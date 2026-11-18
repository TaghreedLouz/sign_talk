#!/usr/bin/env python3
"""Small GRU-CTC baseline for gloss recognition; not an English translator."""
import argparse, json, random
from pathlib import Path
import numpy as np
import pandas as pd
import torch
from torch import nn
from torch.nn.utils.rnn import pad_sequence, pack_padded_sequence

FEATURES = 2582

def set_seed(seed):
    random.seed(seed); np.random.seed(seed); torch.manual_seed(seed)

def load_items(df, data_dir, vocab):
    items = []
    for row in df.itertuples(index=False):
        p = data_dir / f"{row.clip_id}.npz"
        if not p.exists():
            raise FileNotFoundError(f"Missing prepared feature file: {p}")
        with np.load(p) as z:
            x = np.asarray(z["features"], dtype=np.float32)
            y = np.asarray(z["gloss_ids"], dtype=np.int64)
        if x.ndim != 2 or x.shape[1] != FEATURES or x.shape[0] < 2:
            raise ValueError(f"{p}: expected features [T,{FEATURES}], got {x.shape}")
        if y.ndim != 1 or len(y) == 0:
            raise ValueError(f"{p}: gloss_ids must be a non-empty vector")
        if np.any(y <= 0) or np.any(y >= vocab):
            raise ValueError(f"{p}: gloss token ID outside 1..{vocab-1}; 0 is reserved for CTC blank")
        items.append((torch.from_numpy(x), torch.from_numpy(y)))
    if not items: raise ValueError("No training items found.")
    return items

def collate(batch):
    xs, ys = zip(*batch)
    lengths = torch.tensor([len(x) for x in xs], dtype=torch.long)
    xpad = pad_sequence(xs, batch_first=True)
    ycat = torch.cat(ys)
    ylen = torch.tensor([len(y) for y in ys], dtype=torch.long)
    return xpad, lengths, ycat, ylen

class GlossGRUCTC(nn.Module):
    def __init__(self, hidden, vocab_size):
        super().__init__()
        self.norm = nn.LayerNorm(FEATURES)
        self.gru = nn.GRU(FEATURES, hidden, num_layers=2, batch_first=True,
                          bidirectional=True, dropout=0.2)
        self.head = nn.Linear(hidden * 2, vocab_size)
    def forward(self, x, lengths):
        x = self.norm(x)
        packed = pack_padded_sequence(x, lengths.cpu(), batch_first=True, enforce_sorted=False)
        packed_out, _ = self.gru(packed)
        out, out_lengths = torch.nn.utils.rnn.pad_packed_sequence(packed_out, batch_first=True)
        return self.head(out).log_softmax(-1).transpose(0, 1), out_lengths

def greedy_decode(log_probs, lengths, blank=0):
    pred = log_probs.argmax(-1).transpose(0,1).cpu().numpy()
    results = []
    for seq, n in zip(pred, lengths.cpu().numpy()):
        out, prev = [], None
        for token in seq[:n]:
            if token != blank and token != prev: out.append(int(token))
            prev = token
        results.append(out)
    return results

def edit_distance(a, b):
    prev = list(range(len(b)+1))
    for i, x in enumerate(a, 1):
        cur = [i]
        for j, y in enumerate(b, 1):
            cur.append(min(cur[-1]+1, prev[j]+1, prev[j-1]+(x != y)))
        prev = cur
    return prev[-1]

def evaluate(model, loader, device, loss_fn):
    model.eval(); total_loss = 0.; total_ed = 0; total_ref = 0
    with torch.no_grad():
        for x, xlen, ycat, ylen in loader:
            x, xlen, ycat, ylen = x.to(device), xlen.to(device), ycat.to(device), ylen.to(device)
            lp, outlen = model(x, xlen)
            total_loss += float(loss_fn(lp, ycat, outlen, ylen))
            preds = greedy_decode(lp, outlen)
            offset = 0
            for pred, n in zip(preds, ylen.cpu().tolist()):
                ref = ycat.cpu().tolist()[offset:offset+n]; offset += n
                total_ed += edit_distance(pred, ref); total_ref += len(ref)
    return total_loss / max(1, len(loader)), total_ed / max(1, total_ref)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", type=Path, required=True)
    ap.add_argument("--annotations", type=Path, required=True)
    ap.add_argument("--vocab", type=Path, required=True, help="JSON object with token->ID; IDs start at 1")
    ap.add_argument("--output-dir", type=Path, required=True)
    ap.add_argument("--epochs", type=int, default=30)
    ap.add_argument("--batch-size", type=int, default=8)
    ap.add_argument("--hidden", type=int, default=256)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()
    set_seed(args.seed)
    df = pd.read_csv(args.annotations).fillna("")
    if not {"clip_id", "split"} <= set(df.columns): raise SystemExit("CSV needs clip_id and split columns.")
    vocab = json.loads(args.vocab.read_text(encoding="utf-8"))
    if not vocab or sorted(vocab.values()) != list(range(1, len(vocab)+1)):
        raise SystemExit("Vocabulary IDs must be contiguous integers starting at 1; 0 is CTC blank.")
    train_df, val_df = df[df.split=="train"], df[df.split=="validation"]
    if train_df.empty or val_df.empty: raise SystemExit("Need non-empty train and validation signer splits.")
    train_items = load_items(train_df, args.data_dir, len(vocab)+1)
    val_items = load_items(val_df, args.data_dir, len(vocab)+1)
    train_loader = torch.utils.data.DataLoader(train_items, batch_size=args.batch_size, shuffle=True, collate_fn=collate)
    val_loader = torch.utils.data.DataLoader(val_items, batch_size=args.batch_size, shuffle=False, collate_fn=collate)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = GlossGRUCTC(args.hidden, len(vocab)+1).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr)
    loss_fn = nn.CTCLoss(blank=0, zero_infinity=True)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    best = float("inf")
    for epoch in range(1, args.epochs+1):
        model.train(); running = 0.
        for x, xlen, ycat, ylen in train_loader:
            x, xlen, ycat, ylen = x.to(device), xlen.to(device), ycat.to(device), ylen.to(device)
            optimizer.zero_grad(set_to_none=True)
            lp, outlen = model(x, xlen)
            loss = loss_fn(lp, ycat, outlen, ylen)
            if not torch.isfinite(loss): raise RuntimeError("Non-finite CTC loss; inspect labels and sequence lengths.")
            loss.backward(); nn.utils.clip_grad_norm_(model.parameters(), 5.0); optimizer.step()
            running += float(loss.detach())
        val_loss, val_gloss_wer = evaluate(model, val_loader, device, loss_fn)
        print(f"epoch={epoch} train_loss={running/max(1,len(train_loader)):.4f} val_loss={val_loss:.4f} val_gloss_WER={val_gloss_wer:.4f} device={device}")
        if val_loss < best:
            best = val_loss
            torch.save({"model_state": model.state_dict(), "vocab": vocab,
                        "feature_schema": "signtalk.holistic.2582.v1",
                        "feature_count": FEATURES, "epoch": epoch,
                        "validation_gloss_wer": val_gloss_wer},
                       args.output_dir / "best_gru_ctc.pt")
    print("Training complete. This is a gloss baseline only; no English sentence translation or Android readiness is implied.")

if __name__ == "__main__":
    main()

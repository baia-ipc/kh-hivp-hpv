# Legacy HPVC Centrifuge Factory Notes

This note preserves the legacy "factory" material that used to live under
`/srv/databases/centrifuge/hpvc/20231030/factory/`.

That factory directory was not the real provenance of the deployed HPVC
database. The actual HPVC index was obtained as a prebuilt download, using the
recipe now documented in `/srv/databases/centrifuge/hpvc/README.md`:

```bash
rm -f h+p+v+c.tar.gz?download=1
wget https://zenodo.org/record/3732127/files/h+p+v+c.tar.gz?download=1
mv h+p+v+c.tar.gz?download=1 h+p+v+c.tar.gz
tar -xvf h+p+v+c.tar.gz
```

The obsolete factory files were kept here as a historical record before
removal from the shared database directory and from this repository.

## Legacy shell snippets

File: `1_d_tax.sh`

```bash
centrifuge-download -o /srv/giorgio/refdata/centrifuge/taxonomy-2023-10-30 taxonomy
```

File: `2_d_human.sh`

```bash
centrifuge-download -o /srv/giorgio/refdata/centrifuge/human -d "vertebrate_mammalian" -a "Chromosome" -t 9606 -c 'reference genome' refseq >> seqid2taxid.map
```

File: `3_d_refseq_v.sh`

```bash
centrifuge-download -o /srv/giorgio/refdata/centrifuge/factory/viral -d 'viral' refseq > viral_seqid2taxid.map
```

## Operational note

The taxonomy dump needed by the bucketing pipeline remains part of the shared
installation, but it now lives outside `factory/` at:

`/srv/databases/centrifuge/hpvc/latest/taxonomy-2023-10-30`

The pipeline default in `config/user.config` was updated to use that path.

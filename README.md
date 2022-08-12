#  NIST LWC Hardware Reference Implementation of [ISAP v2.0](https://isap.iaik.tugraz.at)

- Hardware Design Group: Institute of Applied Information Processing and Communications, Graz, Austria
- Primary Hardware Designers:
  - Robert Primas (https://rprimas.github.io, rprimas@proton.me)
- LWC candidate: ISAP
- LWC Hardware API version: 1.2.0

ISAP is a family of lightweight authenticated encryption algorithms designed with a focus on robustness against implementation attacks and is currently competing in the final round of the NIST Standardization Process for [Lightweight Cryptography](https://csrc.nist.gov/Projects/lightweight-cryptography/finalists) (2019-). It is of particular interest for applications like firmware updates where robustness against power analysis and fault attacks is crucial while codesize and a small footprint in hardware matters. ISAP's original version was published at FSE 2017.

## Available Variants

- **v1** : `isapa128av20 + asconhashv12, 32-bit interface, 1 permutation round per clock cycle`
- **v1_8bit** : `isapa128av20 + asconhashv12, 8-bit interface, 1 permutation round per clock cycle`
- **v1_16bit** : `isapa128av20 + asconhashv12, 16-bit interface, 1 permutation round per clock cycle`
- **v1_lowlatency** : `isapa128av20 + asconhashv12, 32-bit interface, 2 permutation rounds per clock cycle`
- **v1_stp** : `isapa128av20 + asconhashv12, 32-bit interface, 1 permutation round per clock cycle, StP-based tag verification`
- **v2** : `isapk128av20, 16-bit interface, 1 permutation round per clock cycle`

## Folders

- `hardware`: HDL sources and testbench scripts.
- `software`: Software reference implementation and Known-Answer-Test (KAT) generation scripts.

## Quick Start

- Install the GHDL open-source VHDL simulator (tested with version 0.37 and 1.0 and 2.0):
  - `sudo apt install ghdl`
- Execute VHDL testbench for v1 (or other variants):
  - `cd hardware/isap_lwc`
  - `make v1`

## Generating New Testvectors from Software

- Install testvector generation scripts:
  - `pip install software/cryptotvgen`
- Compile Ascon software reference implementations:
  - `cryptotvgen --prepare_libs --candidates_dir=software/isap_ref`
- Locate testvector generation scripts:
  - `cd software/cryptotvgen/examples`
- Run (and optionally modify) a testvector generation script:
  - `python genkat_v1.py`
- Replace existing testvectors (KAT) of v1 with the newley generated ones:
  - `mv testvectors/v1_32 testvectors/v1`
  - `rm -r ../../../hardware/isap_lwc/KAT/v1`
  - `mv testvectors/v1 ../../../hardware/isap_lwc/KAT`
- Execute VHDL testbench for v1:
  - `cd ../../../hardware/isap_lwc`
  - `make v1`


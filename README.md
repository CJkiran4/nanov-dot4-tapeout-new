# NanoV RV32E + MMIO INT8 Dot4 — OpenLane 2 (SKY130)

This repository contains the v6 project archive and a launcher for the project's **exploratory OpenLane 2** run.

## Important status

The launcher was syntax-checked and the archived configuration's DESIGN_NAME was checked against the declared top module. The complete OpenLane flow has **not** been run from this repository yet. A generated GDS, if the flow succeeds, does not by itself prove Tiny Tapeout tile fit or fabrication signoff.

The checked-in nanov_dot4_project_v6.tar.gz contains:
- nanov_dot4/openlane/config.json
- nanov_dot4/openlane/run_openlane.sh
- nanov_dot4/rtl/ and nanov_dot4/tt/src/
- testbenches, FPGA scripts and reports

The OpenLane configuration currently uses DESIGN_NAME=tt_um_nanov_dot4_accel, CLOCK_PORT=clk, CLOCK_PERIOD=83.33 ns (about 12 MHz), and relative floorplan sizing. This is exploratory sizing, not the fixed Tiny Tapeout tile flow.

## Run on Ubuntu or WSL2

Install Docker Engine (Ubuntu) or Docker Desktop with WSL integration (Windows/WSL2), and Git/Python. Follow the official OpenLane 2 Docker installation guide:
https://openlane2.readthedocs.io/en/latest/getting_started/common/docker_installation/index.html

Then:

```bash
sudo apt-get update
sudo apt-get install -y git tar python3-venv python3-pip

git clone https://github.com/CJkiran4/nanov-dot4-tapeout-new.git
cd nanov-dot4-tapeout-new

python3 -m venv ~/venvs/openlane2
source ~/venvs/openlane2/bin/activate
python -m pip install --upgrade pip
python -m pip install openlane

docker --version
docker info
python -m openlane --dockerized --smoke-test

chmod +x run_openlane2.sh
./run_openlane2.sh
```

The script extracts the archive into ~/work/nanov_dot4_openlane/nanov_dot4, synchronizes the copies under tt/src, checks the config top module, runs openlane --dockerized config.json, saves a timestamped log under ~/work/nanov_dot4_openlane/logs, and lists any GDS/report outputs.

If the script stops at Docker checks, fix Docker first. If OpenLane fails, preserve the log and diagnose the first actual error before changing RTL or timing constraints.

## Results to inspect

Under ~/work/nanov_dot4_openlane/nanov_dot4/openlane/runs/, review:
- final GDSII output;
- metrics JSON and synthesis/placement/routing reports;
- setup and hold slack;
- routing completion and congestion;
- antenna and DRC/LVS reports, where the flow produces them.

The source archive notes unresolved items including the provisional Tiny Tapeout tiles: "2x2" allocation, the scan-flop configuration in multiply.v, and missing external SPI-pin I/O timing constraints. Confirm the selected shuttle's actual requirements and run its official Tiny Tapeout flow separately before claiming tapeout readiness.

## Repository visibility

Check the repository's GitHub Settings → General → Danger Zone → Change repository visibility if this project should be private. Make sure visibility matches your intention before sharing the link.

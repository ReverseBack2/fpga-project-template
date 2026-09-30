PYTHON ?= python3
.PHONY: sim simview lint clean
sim:
	$(PYTHON) sim/run.py
simview:
	$(PYTHON) sim/run.py --view
lint:
	$(PYTHON) sim/run.py --lint
clean:
	$(PYTHON) sim/run.py --clean

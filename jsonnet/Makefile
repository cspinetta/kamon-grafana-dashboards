SHELL=/bin/bash
DATE=$(shell date -I)
OUT_GRAFANA=out/grafana
GRAFANA_TARGETS=$(patsubst %.jsonnet, $(OUT_GRAFANA)/%.json, $(wildcard dash*.jsonnet))

ALL_JSONNET=$(wildcard *.jsonnet)
ALL_SONNETS=$(wildcard *.*sonnet)

all: $(GRAFANA_TARGETS)

test: test-fmt

test-fmt:
	jsonnetfmt --test $(ALL_SONNETS)

fix-fmt:
	for i in $(ALL_SONNETS); do jsonnetfmt -i $$i;done

clean:
	rm -f $(GRAFANA_TARGETS)

$(OUT_GRAFANA)/%.json: %.jsonnet
	@mkdir -p out/grafana
	jsonnet $(<) > $(@).tmp && mv $(@).tmp $(@) || rm -f $(@).tmp

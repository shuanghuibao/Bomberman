# 本地快捷命令（需 godot 在 PATH 中，或设置 GODOT 环境变量）
GODOT ?= godot

.PHONY: test lint run

test:
	$(GODOT) --headless -s tests/test_runner.gd

lint:
	@EXIT=0; \
	for f in $$(find scripts tests -name '*.gd'); do \
		$(GODOT) --headless --check-only -s "$$f" 2>&1 || EXIT=1; \
	done; \
	exit $$EXIT

run:
	$(GODOT) --path .

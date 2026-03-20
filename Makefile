
build:
	@mush build --release

push:
	@git add .
	@git commit -am "Small fix" || true
	@git push

release: build push
	@echo "Release complete."

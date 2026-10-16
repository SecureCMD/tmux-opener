.PHONY: app install run zip universal clean

app:            ## Build "build/Tmux Opener.app"
	@scripts/build.sh

install:        ## Build and copy to /Applications
	@scripts/build.sh --install

run: app        ## Build and launch
	@open "build/Tmux Opener.app"

zip:            ## Build a distributable zip
	@scripts/build.sh --zip

universal:      ## Universal (arm64 + x86_64) zip, needs Xcode
	@scripts/build.sh --universal --zip

clean:
	rm -rf .build build

.PHONY: app install run zip universal release clean

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

release:        ## Signed + notarized universal zip (SIGN_IDENTITY, NOTARY_PROFILE)
	@scripts/build.sh --universal --zip --notarize

clean:
	rm -rf .build build

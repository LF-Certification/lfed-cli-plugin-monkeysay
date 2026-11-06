// Command lfed-monkeysay is the lfed example plugin.
package main

import (
	"go.ed.linuxfoundation.org/lfed/sdk/iostreams"
	"go.ed.linuxfoundation.org/lfed/sdk/plugin"

	"github.com/LF-Certification/lfed-cli-plugin-monkeysay/internal/cmd"
)

// Version MUST be semver. Release builds set it with -X main.Version.
var Version = "0.0.0-dev"

func main() {
	plugin.Serve(cmd.New(iostreams.System()), plugin.Manifest{
		Name:         "monkeysay",
		Version:      Version,
		Summary:      "Print a message in a speech balloon over an ASCII monkey.",
		RequiresLfed: ">=0.1.0 <1",
	})
}

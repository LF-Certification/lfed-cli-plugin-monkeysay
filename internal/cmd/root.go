// Package cmd builds the lfed-monkeysay command tree.
package cmd

import (
	"errors"
	"io"
	"strings"

	"github.com/spf13/cobra"
	"go.ed.linuxfoundation.org/lfed/sdk/iostreams"
	"go.ed.linuxfoundation.org/lfed/sdk/plugin"

	"github.com/LF-Certification/lfed-cli-plugin-monkeysay/internal/monkey"
)

type result struct {
	Text string `json:"text"`
	Art  string `json:"art"`
}

// New returns the root command wired to ios.
func New(ios *iostreams.IOStreams) *cobra.Command {
	var width int
	cmd := &cobra.Command{
		Use:   "lfed-monkeysay [text...]",
		Short: "Print a message in a speech balloon over an ASCII monkey",
		// The SDK adds the __metadata subcommand; without this cobra rejects text as an unknown command.
		Args: cobra.ArbitraryArgs,
		Long: `Print a message in a speech balloon over an ASCII monkey.

Without arguments the message is read from standard input.`,
		Example: `  lfed monkeysay hello world
  echo hello | lfed monkeysay
  lfed monkeysay -o json --jq .text hello`,
		RunE: func(cmd *cobra.Command, args []string) error {
			text, err := message(cmd, ios, args)
			if err != nil {
				return err
			}
			p, err := plugin.Printer(cmd)
			if err != nil {
				return err
			}
			art := monkey.Say(text, width)
			if p.Mode.Structured() {
				return p.PrintValue(result{Text: text, Art: art})
			}
			_, err = io.WriteString(cmd.OutOrStdout(), art)
			return err
		},
	}
	cmd.Flags().IntVar(&width, "width", 40, "Maximum balloon width in characters")
	cmd.SetIn(ios.In)
	cmd.SetOut(ios.Out)
	cmd.SetErr(ios.ErrOut)
	return cmd
}

func message(cmd *cobra.Command, ios *iostreams.IOStreams, args []string) (string, error) {
	if len(args) > 0 {
		return strings.Join(args, " "), nil
	}
	if ios.IsStdinTTY() {
		// The SDK flag error func marks the error as a usage error: exit code 2.
		return "", cmd.FlagErrorFunc()(cmd, errors.New("no text given and standard input is a terminal"))
	}
	b, err := io.ReadAll(cmd.InOrStdin())
	if err != nil {
		return "", err
	}
	return strings.TrimRight(string(b), "\n"), nil
}

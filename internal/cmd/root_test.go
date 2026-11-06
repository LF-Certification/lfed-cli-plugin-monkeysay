package cmd

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"go.ed.linuxfoundation.org/lfed/sdk/iostreams"
	"go.ed.linuxfoundation.org/lfed/sdk/plugin"
)

func run(t *testing.T, stdin string, stdinTTY bool, args ...string) (out, errOut string, err error) {
	t.Helper()
	ios, in, outBuf, errBuf := iostreams.Test()
	in.WriteString(stdin)
	ios.SetStdinTTY(stdinTTY)
	root := New(ios)
	plugin.Prepare(root, plugin.Manifest{Name: "monkeysay"})
	root.SetArgs(args)
	err = root.Execute()
	return outBuf.String(), errBuf.String(), err
}

func TestRoot(t *testing.T) {
	t.Run("text from args", func(t *testing.T) {
		out, _, err := run(t, "", false, "hello", "world")
		if err != nil {
			t.Fatal(err)
		}
		want := " _____________\n< hello world >\n -------------\n"
		if !strings.HasPrefix(out, want) || !strings.Contains(out, "( ( o o ) )") {
			t.Errorf("unexpected output:\n%s", out)
		}
	})

	t.Run("text from stdin", func(t *testing.T) {
		out, _, err := run(t, "piped\n", false)
		if err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(out, "< piped >") {
			t.Errorf("unexpected output:\n%s", out)
		}
	})

	t.Run("width wraps", func(t *testing.T) {
		out, _, err := run(t, "", false, "--width", "5", "ab cde")
		if err != nil {
			t.Fatal(err)
		}
		if !strings.HasPrefix(out, " _____\n/ ab  \\\n\\ cde /\n -----\n") {
			t.Errorf("unexpected output:\n%s", out)
		}
	})

	t.Run("json", func(t *testing.T) {
		out, _, err := run(t, "", false, "-o", "json", "hi")
		if err != nil {
			t.Fatal(err)
		}
		var got result
		if err := json.Unmarshal([]byte(out), &got); err != nil {
			t.Fatalf("invalid json %q: %v", out, err)
		}
		if got.Text != "hi" || !strings.HasPrefix(got.Art, " ____\n< hi >\n") {
			t.Errorf("unexpected result %+v", got)
		}
	})

	t.Run("jq", func(t *testing.T) {
		out, _, err := run(t, "", false, "--jq", ".text", "hi")
		if err != nil {
			t.Fatal(err)
		}
		if out != "hi\n" {
			t.Errorf("unexpected output %q", out)
		}
	})

	t.Run("tty without args is a usage error", func(t *testing.T) {
		out, _, err := run(t, "", true)
		if err == nil {
			t.Fatal("expected an error")
		}
		// The SDK exits 2 only for its own flag error type. A flag parse
		// error carries that type; ours MUST carry the same one.
		_, _, flagErr := run(t, "", false, "--no-such-flag")
		if flagErr == nil || reflect.TypeOf(err) != reflect.TypeOf(flagErr) {
			t.Errorf("error %T is not a usage error like %T", err, flagErr)
		}
		if out != "" {
			t.Errorf("unexpected output %q", out)
		}
	})
}

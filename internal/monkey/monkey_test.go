package monkey

import (
	"reflect"
	"strings"
	"testing"
)

func TestWrap(t *testing.T) {
	tests := []struct {
		name  string
		text  string
		width int
		want  []string
	}{
		{"empty", "", 10, []string{""}},
		{"whitespace only", "  \n\t ", 10, []string{""}},
		{"fits", "hello world", 40, []string{"hello world"}},
		{"wraps at width", "the quick brown fox", 9, []string{"the quick", "brown fox"}},
		{"exact width", "ab cd", 5, []string{"ab cd"}},
		{"one over width", "ab cde", 5, []string{"ab", "cde"}},
		{"long word kept whole", "a verylongword b", 4, []string{"a", "verylongword", "b"}},
		{"collapses whitespace", "a   b\n\nc", 40, []string{"a b c"}},
		{"multibyte runes", "héllo wörld", 5, []string{"héllo", "wörld"}},
		{"width below one", "a b", 0, []string{"a", "b"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Wrap(tt.text, tt.width); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("Wrap(%q, %d) = %q, want %q", tt.text, tt.width, got, tt.want)
			}
		})
	}
}

func TestBalloon(t *testing.T) {
	tests := []struct {
		name  string
		lines []string
		want  string
	}{
		{
			name:  "nil",
			lines: nil,
			want:  " __\n<  >\n --\n",
		},
		{
			name:  "one line",
			lines: []string{"hi"},
			want:  " ____\n< hi >\n ----\n",
		},
		{
			name:  "two lines padded",
			lines: []string{"hello", "yo"},
			want:  " _______\n/ hello \\\n\\ yo    /\n -------\n",
		},
		{
			name:  "three lines",
			lines: []string{"a", "b", "c"},
			want:  " ___\n/ a \\\n| b |\n\\ c /\n ---\n",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Balloon(tt.lines); got != tt.want {
				t.Errorf("Balloon(%q) =\n%s\nwant\n%s", tt.lines, got, tt.want)
			}
		})
	}
}

func TestSay(t *testing.T) {
	got := Say("hello world", 40)
	if !strings.HasPrefix(got, " _____________\n< hello world >\n -------------\n") {
		t.Errorf("Say balloon mismatch:\n%s", got)
	}
	if !strings.HasSuffix(got, art) {
		t.Errorf("Say does not end with the monkey:\n%s", got)
	}
}

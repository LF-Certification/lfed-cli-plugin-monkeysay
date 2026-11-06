// Package monkey renders text as a speech balloon over an ASCII monkey.
package monkey

import (
	"strings"
	"unicode/utf8"
)

// art is a monkey by Joan G. Stark (jgs), https://www.asciiart.eu/animals/monkeys.
var art = strings.Join([]string{
	`        \`,
	`         \`,
	`       .="=.`,
	`     _/.-.-.\_     _`,
	`    ( ( o o ) )    ))`,
	`     |/  "  \|    //`,
	`      \'---'/    //`,
	"jgs   /`\"\"\"`\\\\  ((",
	`     / /_,_\ \\  \\`,
	`     \_\\_'__/ \  ))`,
	"     /`  /`~\\  |//",
	`    /   /    \  /`,
	",--`,--'\\/\\    /",
	` '-- "--'  '--'`,
	``,
}, "\n")

// Wrap splits text into lines of at most width runes. A word longer than
// width is kept on its own line.
func Wrap(text string, width int) []string {
	if width < 1 {
		width = 1
	}
	words := strings.Fields(text)
	if len(words) == 0 {
		return []string{""}
	}
	var lines []string
	line := words[0]
	for _, w := range words[1:] {
		if utf8.RuneCountInString(line)+1+utf8.RuneCountInString(w) > width {
			lines = append(lines, line)
			line = w
			continue
		}
		line += " " + w
	}
	return append(lines, line)
}

// Balloon draws a speech balloon around lines. Lines are padded to the
// longest line.
func Balloon(lines []string) string {
	if len(lines) == 0 {
		lines = []string{""}
	}
	width := 0
	for _, l := range lines {
		if n := utf8.RuneCountInString(l); n > width {
			width = n
		}
	}
	var b strings.Builder
	b.WriteString(" " + strings.Repeat("_", width+2) + "\n")
	for i, l := range lines {
		left, right := "|", "|"
		switch {
		case len(lines) == 1:
			left, right = "<", ">"
		case i == 0:
			left, right = "/", "\\"
		case i == len(lines)-1:
			left, right = "\\", "/"
		}
		pad := strings.Repeat(" ", width-utf8.RuneCountInString(l))
		b.WriteString(left + " " + l + pad + " " + right + "\n")
	}
	b.WriteString(" " + strings.Repeat("-", width+2) + "\n")
	return b.String()
}

// Say returns the balloon for text wrapped at width, over the monkey.
func Say(text string, width int) string {
	return Balloon(Wrap(text, width)) + art
}

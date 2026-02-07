package main

import (
	"fmt"
	"os"
)

// The frontend dist directory is embedded via go:embed in builds that include Wails.
// For builds without Wails (testing, CI), this file provides a standalone entry point.
//
// When building with Wails:
//   //go:embed all:frontend/dist
//   var assets embed.FS
//
// Build with: wails build -platform <target>

func main() {
	fmt.Println("AutoPaqet GUI")
	fmt.Println("=============")
	fmt.Println()
	fmt.Println("This binary requires Wails v2 runtime to display the GUI.")
	fmt.Println("Build with: cd gui && wails build")
	fmt.Println()
	fmt.Println("For development: cd gui && wails dev")
	os.Exit(0)
}

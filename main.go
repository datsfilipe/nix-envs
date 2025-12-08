package main

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
)

const (
	ColorReset  = "\033[0m"
	ColorRed    = "\033[31m"
	ColorGreen  = "\033[32m"
	ColorYellow = "\033[33m"
	ColorBlue   = "\033[34m"
)

func main() {
	if len(os.Args) < 2 {
		showHelp()
		os.Exit(1)
	}

	command := os.Args[1]
	args := os.Args[2:]

	switch command {
	case "create":
		handleCreate(args)
	case "edit":
		handleEdit(args)
	case "delete":
		handleDelete(args)
	default:
		showHelp()
	}
}

func handleCreate(args []string) {
	if len(args) < 2 {
		fatal("Usage: nix-envs create <template> <version> [--track]")
	}

	template := args[0]
	version := args[1]
	track := contains(args, "--track")

	projectName := getProjectName()
	cacheDir := getCacheDir(projectName, template)

	fmt.Printf("%sCreating %s environment (%s) for project %s...%s\n", ColorBlue, template, version, projectName, ColorReset)

	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		fatal("Failed to create cache directory: " + err.Error())
	}

	var flakeContent string
	var err error

	switch template {
	case "nodejs":
		flakeContent, err = generateNodeJS(version)
	case "go":
		flakeContent = generateGo(version)
	case "rust":
		flakeContent = generateRust(version)
	case "python":
		flakeContent = generatePython(version)
	case "bun":
		flakeContent = generateBun()
	default:
		fatal("Unknown template: " + template)
	}

	if err != nil {
		fatal(err.Error())
	}

	flakePath := filepath.Join(cacheDir, "flake.nix")
	if err := os.WriteFile(flakePath, []byte(flakeContent), 0644); err != nil {
		fatal("Failed to write flake.nix: " + err.Error())
	}

	setupEnvrc(cacheDir)
	if !track {
		setupGitIgnore()
	}

	fmt.Printf("%sSuccess! Environment ready in %s%s\n", ColorGreen, cacheDir, ColorReset)
}

func handleEdit(args []string) {
	if len(args) < 1 {
		fatal("Usage: nix-envs edit <template>")
	}
	template := args[0]
	projectName := getProjectName()
	flakePath := filepath.Join(getCacheDir(projectName, template), "flake.nix")

	if _, err := os.Stat(flakePath); os.IsNotExist(err) {
		fatal("Environment does not exist. Create it first.")
	}

	fmt.Printf("Opening %s with xdg-open...\n", flakePath)

	cmd := exec.Command("xdg-open", flakePath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		fatal(fmt.Sprintf("Failed to run xdg-open: %v", err))
	}
}

func handleDelete(args []string) {
	if len(args) < 1 {
		fatal("Usage: nix-envs delete <template>")
	}
	template := args[0]
	projectName := getProjectName()
	cacheDir := getCacheDir(projectName, template)

	if _, err := os.Stat(cacheDir); os.IsNotExist(err) {
		fatal("Environment not found.")
	}

	if err := os.RemoveAll(cacheDir); err != nil {
		fatal("Failed to delete environment: " + err.Error())
	}

	removeFromEnvrc(cacheDir)

	fmt.Printf("%sDeleted %s environment.%s\n", ColorYellow, template, ColorReset)
}

func generateNodeJS(version string) (string, error) {
	arch := "linux-x64"
	if runtime.GOARCH == "arm64" {
		arch = "linux-arm64"
	}

	fmt.Printf("Fetching hash for Node.js v%s...\n", version)
	shasumsUrl := fmt.Sprintf("https://nodejs.org/dist/v%s/SHASUMS256.txt", version)

	resp, err := http.Get(shasumsUrl)
	if err != nil || resp.StatusCode != 200 {
		return "", fmt.Errorf("Could not find version v%s on nodejs.org (HTTP %d)", version, resp.StatusCode)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	bodyString := string(bodyBytes)

	targetFile := fmt.Sprintf("node-v%s-%s.tar.gz", version, arch)
	hash := ""

	scanner := bufio.NewScanner(strings.NewReader(bodyString))
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, targetFile) {
			parts := strings.Fields(line)
			if len(parts) > 0 {
				hash = parts[0]
				break
			}
		}
	}

	if hash == "" {
		return "", fmt.Errorf("Hash not found for %s. Does this version support %s?", version, arch)
	}

	fmt.Printf("%sFound hash: %s%s\n", ColorBlue, hash, ColorReset)

	return fmt.Sprintf(`{
  description = "NodeJS %s Custom Environment";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  
  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    
    nodeCustom = pkgs.stdenv.mkDerivation {
      name = "nodejs-%s";
      src = pkgs.fetchurl {
        url = "https://nodejs.org/dist/v%s/node-v%s-%s.tar.gz";
        sha256 = "%s";
      };
      
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.libuuid ];
      
      installPhase = ''
        mkdir -p $out
        cp -r * $out/
      '';
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [ 
        nodeCustom
        pkgs.python3 # often needed for node-gyp
      ];
      env = {
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.libuuid pkgs.stdenv.cc.cc.lib ];
        NODE_PATH = "$out/lib/node_modules";
      };
    };
  };
}`, version, version, version, version, arch, hash), nil
}

func generateGo(version string) string {
	major := strings.Split(version, ".")[0]
	pkgName := "go"
	if major != "" && major != "go" {
		pkgName = "go_1_" + major
	}

	return fmt.Sprintf(`{
  description = "Go %s Environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.default = pkgs.mkShell {
        packages = [ pkgs.%s pkgs.gopls ];
      };
    });
}`, version, pkgName)
}

func generateRust(version string) string {
	rustVer := "pkgs.rust-bin.stable.latest.default"
	if version != "latest" {
		rustVer = fmt.Sprintf("pkgs.rust-bin.stable.\"%s\".default", version)
	}

	return fmt.Sprintf(`{
  description = "Rust %s Environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      overlays = [ (import rust-overlay) ];
      pkgs = import nixpkgs { inherit system overlays; };
    in {
      devShells.default = pkgs.mkShell {
        packages = [ 
          pkgs.pkg-config 
          pkgs.openssl 
          %s 
          pkgs.rust-analyzer 
        ];
        env = {
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
        };
      };
    });
}`, version, rustVer)
}

func generatePython(version string) string {
	return `{
  description = "Python Environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.default = pkgs.mkShell {
        packages = [ pkgs.python3 pkgs.python3Packages.virtualenv pkgs.python3Packages.pip ];
      };
    });
}`
}

func generateBun() string {
	return `{
  description = "Bun Environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.default = pkgs.mkShell {
        packages = [ pkgs.bun ];
      };
    });
}`
}

func getProjectName() string {
	cmd := exec.Command("git", "rev-parse", "--show-toplevel")
	output, err := cmd.Output()
	if err == nil {
		return filepath.Base(strings.TrimSpace(string(output)))
	}
	wd, _ := os.Getwd()
	return filepath.Base(wd)
}

func getCacheDir(project, template string) string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".cache", "envs", project, template)
}

func setupEnvrc(targetDir string) {
	line := fmt.Sprintf("use flake \"%s\"", targetDir)

	file, err := os.OpenFile(".envrc", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		fatal("Could not open .envrc")
	}
	defer file.Close()

	content, _ := os.ReadFile(".envrc")
	if !strings.Contains(string(content), line) {
		if _, err := file.WriteString(line + "\n"); err != nil {
			fatal("Failed to write to .envrc")
		}
		fmt.Println("Added entry to .envrc")
		exec.Command("direnv", "allow").Run()
	}
}

func removeFromEnvrc(targetDir string) {
	lineToRemove := fmt.Sprintf("use flake \"%s\"", targetDir)
	input, err := os.ReadFile(".envrc")
	if err != nil {
		return
	}

	lines := strings.Split(string(input), "\n")
	var newLines []string
	found := false

	for _, line := range lines {
		if strings.TrimSpace(line) != strings.TrimSpace(lineToRemove) && line != "" {
			newLines = append(newLines, line)
		} else if strings.TrimSpace(line) == strings.TrimSpace(lineToRemove) {
			found = true
		}
	}

	if found {
		output := strings.Join(newLines, "\n")
		if len(output) > 0 {
			output += "\n"
		}
		os.WriteFile(".envrc", []byte(output), 0644)
		fmt.Println("Removed entry from .envrc")
		exec.Command("direnv", "allow").Run()
	}
}

func setupGitIgnore() {
	excludePath := ".git/info/exclude"
	if _, err := os.Stat(".git"); os.IsNotExist(err) {
		return
	}

	f, err := os.OpenFile(excludePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		fmt.Printf("%sWarning: Could not update .git/info/exclude%s\n", ColorYellow, ColorReset)
		return
	}
	defer f.Close()

	content, _ := os.ReadFile(excludePath)
	strContent := string(content)

	ignores := []string{".envrc", ".direnv"}
	for _, ignore := range ignores {
		if !strings.Contains(strContent, ignore) {
			f.WriteString(ignore + "\n")
			fmt.Printf("Added %s to local git exclude\n", ignore)
		}
	}
}

func contains(slice []string, item string) bool {
	return slices.Contains(slice, item)
}

func showHelp() {
	fmt.Println("Usage: nix-envs [command] [template] [version]")
	fmt.Println("\nCommands:")
	fmt.Println("  create <tmpl> <ver>   Create environment (e.g., nodejs 20.11.0)")
	fmt.Println("  edit <tmpl>           Edit the flake")
	fmt.Println("  delete <tmpl>         Remove environment")
}

func fatal(msg string) {
	fmt.Printf("%sError: %s%s\n", ColorRed, msg, ColorReset)
	os.Exit(1)
}

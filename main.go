package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
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
		flakeContent, err = generateGo(version)
	case "rust":
		flakeContent = generateRust(version)
	case "python":
		flakeContent, err = generatePython(version)
	case "bun":
		flakeContent, err = generateBun(version)
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
        pkgs.nodePackages.typescript-language-server
        pkgs.nodePackages.prettier
        pkgs.nodePackages.yarn
        pkgs.nodePackages.pnpm
        pkgs.biome
        pkgs.vscode-langservers-extracted
      ];
      env = {
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.libuuid pkgs.stdenv.cc.cc.lib ];
        NODE_PATH = "$out/lib/node_modules";
      };
    };
  };
}`, version, version, version, version, arch, hash), nil
}

func generateGo(version string) (string, error) {
	arch := "amd64"
	if runtime.GOARCH == "arm64" {
		arch = "arm64"
	}

	osType := "linux"
	filename := fmt.Sprintf("go%s.%s-%s.tar.gz", version, osType, arch)
	hashUrl := fmt.Sprintf("https://dl.google.com/go/%s.sha256", filename)

	fmt.Printf("Fetching hash for Go v%s...\n", version)

	resp, err := http.Get(hashUrl)
	if err != nil || resp.StatusCode != 200 {
		return "", fmt.Errorf("Could not find Go version %s. Checked: %s", version, hashUrl)
	}
	defer resp.Body.Close()

	hashBytes, _ := io.ReadAll(resp.Body)
	hash := strings.TrimSpace(string(hashBytes))

	fmt.Printf("%sFound hash: %s%s\n", ColorBlue, hash, ColorReset)

	return fmt.Sprintf(`{
  description = "Go %s Custom Environment";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    goCustom = pkgs.stdenv.mkDerivation {
      name = "go-%s";
      src = pkgs.fetchurl {
        url = "https://dl.google.com/go/%s";
        sha256 = "%s";
      };

      dontAutoPatchelf = true;
      nativeBuildInputs = [ pkgs.autoPatchelfHook ];
      buildInputs = [ pkgs.stdenv.cc.cc.lib ];

      installPhase = ''
        mkdir -p $out/share/go
        cp -r * $out/share/go
        
        mkdir -p $out/bin
        ln -s $out/share/go/bin/go $out/bin/go
        ln -s $out/share/go/bin/gofmt $out/bin/gofmt
      '';

      postFixup = ''
        autoPatchelf $out/bin
      '';
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [ 
        goCustom
        pkgs.gopls
        pkgs.delve
        pkgs.go-tools
        pkgs.vscode-langservers-extracted
      ];

      shellHook = ''
        export GOROOT=${goCustom}/share/go
        export PATH=$GOROOT/bin:$PATH
      '';
    };
  };
}`, version, version, filename, hash), nil
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
          pkgs.vscode-langservers-extracted
          pkgs.codespell
        ];
        env = {
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
        };
      };
    });
}`, version, rustVer)
}

func generatePython(version string) (string, error) {
	url := fmt.Sprintf("https://www.python.org/ftp/python/%s/Python-%s.tar.xz", version, version)
	fmt.Printf("Fetching Python v%s to calculate hash (this may take a moment)...\n", version)

	resp, err := http.Get(url)
	if err != nil || resp.StatusCode != 200 {
		return "", fmt.Errorf("Could not find Python version %s at %s", version, url)
	}
	defer resp.Body.Close()

	tmpFile, err := os.CreateTemp("", "python-dl-*")
	if err != nil {
		return "", fmt.Errorf("Failed to create temp file: %v", err)
	}
	defer os.Remove(tmpFile.Name()) // Clean up after
	defer tmpFile.Close()

	hasher := sha256.New()
	mw := io.MultiWriter(tmpFile, hasher)

	size, err := io.Copy(mw, resp.Body)
	if err != nil {
		return "", fmt.Errorf("Failed to download Python: %v", err)
	}

	hash := hex.EncodeToString(hasher.Sum(nil))
	fmt.Printf("%sDownloaded %.2f MB. Hash: %s%s\n", ColorBlue, float64(size)/1024/1024, hash, ColorReset)

	return fmt.Sprintf(`{
  description = "Python %s Custom Environment";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    pythonCustom = pkgs.stdenv.mkDerivation {
      name = "python-%s";
      src = pkgs.fetchurl {
        url = "%s";
        sha256 = "%s";
      };

      nativeBuildInputs = [ pkgs.pkg-config ];
      
      buildInputs = [ 
        pkgs.openssl 
        pkgs.zlib 
        pkgs.libffi 
        pkgs.readline 
        pkgs.sqlite 
        pkgs.bzip2 
        pkgs.ncurses
        pkgs.xz
      ];

      configureFlags = [ "--enable-optimizations" ];

      preConfigure = ''
        export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [ pkgs.openssl pkgs.zlib pkgs.stdenv.cc.cc.lib ]}:$LD_LIBRARY_PATH
      '';
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [ 
        pythonCustom
        pkgs.python3Packages.pip
        pkgs.python3Packages.virtualenv
        pkgs.vscode-langservers-extracted
        pkgs.codespell
      ];
      
      env = {
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.openssl pkgs.zlib pkgs.stdenv.cc.cc.lib ];
      };
    };
  };
}`, version, version, url, hash), nil
}

func generateBun(version string) (string, error) {
	arch := "x64"
	if runtime.GOARCH == "arm64" {
		arch = "aarch64"
	}

	fmt.Printf("Fetching hash for Bun v%s...\n", version)
	shasumsUrl := fmt.Sprintf("https://github.com/oven-sh/bun/releases/download/bun-v%s/SHASUMS256.txt", version)

	resp, err := http.Get(shasumsUrl)
	if err != nil || resp.StatusCode != 200 {
		return "", fmt.Errorf("Could not find Bun version v%s (HTTP %d)", version, resp.StatusCode)
	}
	defer resp.Body.Close()

	bodyBytes, _ := io.ReadAll(resp.Body)
	bodyString := string(bodyBytes)

	targetFile := fmt.Sprintf("bun-linux-%s.zip", arch)
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
  description = "Bun %s Environment";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    
    bunCustom = pkgs.stdenv.mkDerivation {
      name = "bun-%s";
      src = pkgs.fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v%s/bun-linux-%s.zip";
        sha256 = "%s";
      };

      nativeBuildInputs = [ pkgs.unzip pkgs.autoPatchelfHook ];

      installPhase = ''
        mkdir -p $out/bin
        cp bun $out/bin/
        chmod +x $out/bin/bun
      '';
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [ 
        bunCustom
        pkgs.nodePackages.typescript-language-server
        pkgs.nodePackages.prettier
        pkgs.biome
        pkgs.vscode-langservers-extracted
      ];
    };
  };
}`, version, version, version, arch, hash), nil
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
	home := os.Getenv("HOME")
	xdg := os.Getenv("XDG_CACHE_HOME")
	if xdg == "" {
		xdg = filepath.Join(home, ".cache")
	}
	return filepath.Join(xdg, "envs", project, template)
}

func setupEnvrc(targetDir string) {
	home := os.Getenv("HOME")
	displayPath := targetDir
	if trimmed, ok := strings.CutPrefix(targetDir, home); ok {
		displayPath = "$HOME" + trimmed
	}

	line := fmt.Sprintf("use flake \"%s\"", displayPath)
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
	home := os.Getenv("HOME")
	displayPath := targetDir
	if trimmed, ok := strings.CutPrefix(targetDir, home); ok {
		displayPath = "$HOME" + trimmed
	}

	lineToRemove := fmt.Sprintf("use flake \"%s\"", displayPath)
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

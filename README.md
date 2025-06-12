# RIT in WINE

## Table of Contents
- [Introduction](#introduction)
- [Method 1: Virtual Machine](#method-1-virtual-machine)
- [Method 2: WINE Wrapper (Recommended)](#method-2-wine-wrapper)
- [Method 3: Manual WINE Installation](#method-3-manual-wine-installation)

## Introduction

We will use Rotman Interactive Trader (RIT), developed by Rotman's Finance Lab, for trading simulation. This software is also used in Rotman's trading competition.

Unfortunately, the software is only available for Windows. Below are several ways to install RIT on a Mac.

## Method 1: Virtual Machine

If you already have a Windows virtual machine on your system, you can install RIT directly on it.

[Download link](https://rit.306w.ca/release/1.8.420/RIT%20User%20Application-1.8.420.msi)

## Method 2: WINE Wrapper

WINE is software that allows you to run some Windows applications on Mac or Linux, bypassing the need for a virtual machine. A wrapper has been created for easier installation.

Open the Terminal app on your Mac (press ⌘+SPACE and search for Terminal.app), then copy and paste the following command:

The terminal will prompt you for your Mac password during installation. When entering your password in Terminal, characters will not appear; simply press return to confirm.

```sh
curl -L "https://www.dropbox.com/scl/fi/df1wx6zbvdw00dh1fvu8w/RIT.dmg?rlkey=kyy2htlpk30oiq6zayqxpn7j8&st=jhzo0t8b&dl=1" -o ~/RIT.dmg && hdiutil attach ~/RIT.dmg -nobrowse -quiet && cp -R /Volumes/RIT/RIT.app /Applications && hdiutil detach /Volumes/RIT -quiet && rm ~/RIT.dmg && (sudo xattr -dr com.apple.quarantine /Applications/RIT.app 2>/dev/null)
```

Once finished, you can launch RIT from your Applications folder.

## Method 3: Manual WINE Installation

If Method 2 fails, please follow the guides below. This method is more involved and requires downloading a few packages, which can also be helpful for other development tasks. Ask Jie for assistance if needed.

[Step 1. Install Homebrew on Mac](doc/install_homebrew.md)

[Step 2. Install WINE and RIT](doc/install_wine.md)


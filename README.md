FS95/FS98 Win64 Patch, version 3 (2026/10/28)
=================================

DISCLAIMER

This was built by [Claude Code](https://claude.com/product/claude-code) Opus 5.5. I only fed Claude Windows Problem Reporting error logs and x32dbg screenshots.
I only created this due to being bored of running *FS95* and *FS98* under VMware and much preferring them to work natively on Windows 10 and 11 like *CFS1*, *FS2000*, and so.
I just like being able to directly access the game files without turning on a virtual environment, let alone the games run better directly on Windows rather than said virtual environment.
Please contribute if you like, maybe add some actual human-written code instead of taking a shortcut like I did.

DIFFERENCES FROM VERSION 2 (2026/10/25)

The patcher has been split into two so both games can be patched independently rather than simultaneously.
This solves the problem of wanting to patch *FS98* but not being able to because the patcher always weirdly needed *FS95* to be present in some way so *FS98* could be done second.

WHAT IT DOES

Fixes *Microsoft Flight Simulator for Windows 95* and *Flight Simulator 98* on 64-bit Windows:
- *FS95* crashing with exception c000041d (top-down view, secondary windows, cycling views, and so on)
- *FS98* crashing at the splash screen
- This does not modify the games in any other way so they look and behave the same way they did in their glory days.

WHY THEY CRASH


Both games deliberately let some integer divisions fail and rely on their own handler, which Microsoft built into the games, to put in a safe result.
On 64-bit Windows that handler can't be reached while the game is handling a window message, so Windows ends the games instead.

The patch adds a small section to FLTSIM95.EXE and FLTSIM98.EXE that also registers the game's own handler in a way 64-bit Windows does call.
It is used only for integer divide faults in the game's own files (anything in the game folder).
Every other error, and any divide fault in Windows or other programs' DLLs, is passed on to Windows exactly as before.
No other game files are changed.

INSTALL

1. Copy these files into the game folder (the one with FLTSIM95.EXE or FLTSIM98.EXE).
   Alternatively, copy both games' EXE files to whatever the hell folder you unzipped this at, then move back the patched EXEs to their respective game's main folder.

2. Close the game, then double-click Patch.bat and allow administrator access when asked.

3. You don't need DxWnd or compatibility settings for these crashes.

4. If you get an error relating to modified EXEs, that involves patching EXEs modified by both games' official patches ("[fsconv.exe](https://web.archive.org/web/19990117005131/microsoft.com/games/fsim/converter.htm)" for FS95; "[fsconv98.exe](https://simviation.com/1/download-file?file=fsconv98.exe)" and "[fs98pat1.exe](https://simviation.com/1/download-file?file=fs98pat1.exe)" for '98.)
   Please patch the original FLTSIM95 and FLTSIM98 EXEs rather than the officially patched ones.
   You can find the originals in the games' CDs or ISOs.
   *FS95*'s is named FLTSIM95.EX_ in the CD so change the extension to EXE then patch.
   Don't worry, the games work fine anyways.

5. The FLTSIM95.EXE inside the *FS98* folder is a dummy to trick *FS95* addon installers into installing into *FS98*.
   It has nothing to do with *FS95* itself. The patcher don't do anything to it anyways, only the real game's EXE.

6. For *FS98*, I suggest using [DDrawCompat](https://github.com/narzoul/DDrawCompat) to fix the hardware renderer's issue displaying the 2D panel, plus other goodies. That also helps with *FS2000* which has the same issue.
   I also suggest that if you install *FS98*'s official patch, backup the original HG2D.DLL and replace the patched version with it,
   as the patched version introduces an annoying bug that wipes out all textures whenever the program's rendering window is clicked at and so on.
   The only expense is the flaps volume will be inconsistent at times.

THE PATCH

- Only changes an EXE that is the original release or an earlier version of this patch (checked by SHA-256), and changes nothing if anything doesn't match.
- Saves the original EXEs as FLTSIM95.EXE.bak and FLTSIM98.EXE.bak.
- Checks the result before writing anything.

UNDO

Double-click Restore.bat. This works even if the .bak file is gone.

ADVANCED

FS95-Win64-Patch.ps1 -GameDir "D:\Games\Flight Simulator 95"   patch another folder
FS95-Win64-Patch.ps1 -Restore                       restore the original

FS98-Win64-Patch.ps1 -GameDir "D:\Games\FS98"   patch another folder
FS98-Win64-Patch.ps1 -Restore        restore the original

This package contains no Microsoft code: only the bytes the patch adds, plus the original header values and zero padding needed to undo it.
I don't feel like dealing with lawyers coming after me for messing with decades-old games that nobody cares about anymore.

Expected SHA-256 values:
  FLTSIM95.EXE  original  1076F5618D84A3790B0A244D4B5DC44D19B1CA6AAAE085378E76F7AA47184EA0
                patched   D671A56E7A27CFD74DFA13BAD48937F7788F64C268E514FE83B2DE8366694C53
  FLTSIM98.EXE  original  F47C124A1AD44475A8A3A5ECBCE83F5DC5D6E7DAD78CF120B20616738BD99F6A
                patched   989C0FC53AB6A863219816B362E5036215B583C8EACF74FC858701400A0B7D85

HOW ABOUT THE IMAGES IN THE ROOT FOLDER

Those are icon upscales utilizing Lospec's [Pixel Art Scaler](https://lospec.com/pixel-art-scaler/), with plenty of manual editing in Microsoft Paint. These were made for fun, that's it.

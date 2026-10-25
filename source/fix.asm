; FS95/FS98 Win64 fix, v3.  Build:  nasm -f bin -DGAME=95|98 [-DHARNESS] fix.asm
; New entry point: registers a vectored exception handler that hands integer
; divide faults (C0000094/C0000095) to the game's own division filter, but only
; when the faulting instruction is NOT inside a DLL located outside the game
; folder. Everything else is passed on untouched (EXCEPTION_CONTINUE_SEARCH).
bits 32
%if GAME == 95
  %define SECT_VA   0x41F000
  %define DATA_VA   0x417220
  %define IAT_GMHA  0x4186A8
  %define IAT_GPA   0x418648
  %define OEP       0x412B70
%else
  %define SECT_VA   0x421000
  %define DATA_VA   0x41C5D0
  %define IAT_GMHA  0x41D740
  %define IAT_GPA   0x41D798
  %define OEP       0x414CE0
%endif
%ifdef HARNESS          ; test build: everything in one blob, fake IAT/data/OEP supplied by harness
  %undef SECT_VA
  %undef DATA_VA
  %undef IAT_GMHA
  %undef IAT_GPA
  %undef OEP
  %define SECT_VA   0x50000000
  %define DATA_VA   0x50001000
  %define IAT_GMHA  0x50001800
  %define IAT_GPA   0x50001804
  %define OEP       0x50001808
%endif

; ---- writable data, in unused space after .data's last byte ----
g_filter equ DATA_VA+0x00   ; game's filter, LONG __stdcall f(EXCEPTION_POINTERS*)
g_gmhex  equ DATA_VA+0x04   ; GetModuleHandleExA
g_gmfn   equ DATA_VA+0x08   ; GetModuleFileNameA
g_glpn   equ DATA_VA+0x0C   ; GetLongPathNameA (optional)
g_dirlen equ DATA_VA+0x10   ; length of game folder incl. trailing '\'; 0 = location check off
g_next   equ DATA_VA+0x14   ; cache slot to replace next
g_cache  equ DATA_VA+0x18   ; 4 dwords: HMODULE | verdict (1 = game file, 2 = elsewhere)
g_dir    equ DATA_VA+0x28   ; game folder, long path form, 264 bytes
DATA_SIZE equ 0x28+264

org SECT_VA

entry:
  pushad
  sub esp,264                          ; temp path buffer
%if GAME == 95
  push sz_divtrap
  call [IAT_GMHA]                      ; DIVTRAP.DLL is a static import: already loaded
  test eax,eax
  jz .done
  lea esi,[eax+0x1010]                 ; DIVTRAP's division filter
  cmp dword [esi],0x83EC8B55           ; push ebp / mov ebp,esp / sub esp,..
  jne .done
  mov [g_filter],esi
%else
  mov dword [g_filter],0x4119A0        ; FLTSIM98's division filter
%endif
  push sz_kernel32
  call [IAT_GMHA]
  test eax,eax
  jz .done
  mov ebx,eax
  push sz_avh
  push ebx
  call [IAT_GPA]
  test eax,eax
  jz .done
  mov ebp,eax                          ; AddVectoredExceptionHandler
  push sz_gmhex
  push ebx
  call [IAT_GPA]
  mov [g_gmhex],eax
  push sz_gmfn
  push ebx
  call [IAT_GPA]
  mov [g_gmfn],eax
  push sz_glpn
  push ebx
  call [IAT_GPA]
  mov [g_glpn],eax
  ; game folder = folder of this EXE, converted to long-path form
  cmp dword [g_gmhex],0
  je .reg
  mov eax,[g_gmfn]
  test eax,eax
  jz .reg
  mov esi,esp
  push 260
  push esi
  push 0
  call eax                             ; GetModuleFileNameA(NULL, tmp, 260)
  test eax,eax
  jz .reg
  cmp eax,260
  jae .reg
  mov eax,[g_glpn]
  test eax,eax
  jz .copy
  push 264
  push g_dir
  push esi
  call eax                             ; GetLongPathNameA(tmp, g_dir, 264)
  test eax,eax
  jz .copy
  cmp eax,264
  jb .havedir
.copy:
  mov edi,g_dir
  mov ecx,260
  rep movsb
.havedir:
  mov esi,g_dir                        ; dirlen = index of last '\' + 1
  xor ecx,ecx
  xor edx,edx
.scan:
  mov al,[esi+ecx]
  test al,al
  jz .scanned
  inc ecx
  cmp al,'\'
  jne .scan
  mov edx,ecx
  jmp .scan
.scanned:
  mov [g_dirlen],edx                   ; stays 0 if no '\' found: check off
.reg:
  push veh
  push 1
  call ebp                             ; AddVectoredExceptionHandler(1, veh)
.done:
  add esp,264
  popad
  jmp OEP

; LONG __stdcall veh(EXCEPTION_POINTERS* ep)
veh:
  mov eax,[esp+4]
  mov eax,[eax]                        ; EXCEPTION_RECORD*
  mov ecx,[eax]                        ; ExceptionCode
  cmp ecx,0xC0000094
  je .div
  cmp ecx,0xC0000095
  je .div
.pass:
  xor eax,eax                          ; EXCEPTION_CONTINUE_SEARCH
  ret 4
.div:
  cmp dword [g_dirlen],0
  je .game
  push dword [eax+0x0C]                ; ExceptionAddress
  call is_game_code
  test eax,eax
  jz .pass
.game:
  jmp [g_filter]                       ; tail call: same argument, same return address

; BOOL __stdcall is_game_code(void* addr)
; FALSE only if addr is inside a module whose file is outside the game folder.
is_game_code:
  push ebp
  mov ebp,esp
  sub esp,4+264+264                    ; [ebp-4] hmod, [ebp-268] path, [ebp-532] long path
  push ebx
  push esi
  push edi
  lea eax,[ebp-4]
  push eax
  push dword [ebp+8]
  push 6                               ; FROM_ADDRESS | UNCHANGED_REFCOUNT
  call [g_gmhex]
  test eax,eax
  jz .yes                              ; not inside any module
  mov ebx,[ebp-4]
  test ebx,0xFFFF
  jnz .nocache                         ; module bases are 64K-aligned; be safe anyway
  mov esi,g_cache
  mov ecx,4
.look:
  mov eax,[esi]
  mov edx,eax
  and edx,0xFFFF0000
  cmp edx,ebx
  jne .next
  and eax,3
  jnz .verdict
.next:
  add esi,4
  loop .look
.nocache:
  lea edi,[ebp-268]
  push 260
  push edi
  push ebx
  call [g_gmfn]
  test eax,eax
  jz .yes                              ; unsure: treat as game code (current behaviour)
  cmp eax,260
  jae .yes
  mov esi,edi
  mov eax,[g_glpn]
  test eax,eax
  jz .compare
  lea edx,[ebp-532]
  push 264
  push edx
  push edi
  call eax
  test eax,eax
  jz .compare
  cmp eax,264
  jae .compare
  lea esi,[ebp-532]
.compare:                              ; ASCII case-insensitive prefix compare with g_dir
  mov edi,g_dir
  mov ecx,[g_dirlen]
.cmploop:
  mov al,[esi]
  mov dl,[edi]
  test al,al
  jz .outside
  cmp al,'A'
  jb .a1
  cmp al,'Z'
  ja .a1
  or al,0x20
.a1:
  cmp dl,'A'
  jb .a2
  cmp dl,'Z'
  ja .a2
  or dl,0x20
.a2:
  cmp al,dl
  jne .outside
  inc esi
  inc edi
  dec ecx
  jnz .cmploop
  mov eax,1
  jmp .store
.outside:
  mov eax,2
.store:
  test ebx,0xFFFF
  jnz .verdict
  mov ecx,[g_next]
  inc dword [g_next]
  and ecx,3
  mov edx,ebx
  or edx,eax
  mov [g_cache+ecx*4],edx              ; one aligned write: safe if threads race
.verdict:
  cmp eax,1
  sete al
  movzx eax,al
  jmp .out
.yes:
  mov eax,1
.out:
  pop edi
  pop esi
  pop ebx
  leave
  ret 4

%if GAME == 95
sz_divtrap:  db 'DIVTRAP.DLL',0
%endif
sz_kernel32: db 'KERNEL32.DLL',0
sz_avh:      db 'AddVectoredExceptionHandler',0
sz_gmhex:    db 'GetModuleHandleExA',0
sz_gmfn:     db 'GetModuleFileNameA',0
sz_glpn:     db 'GetLongPathNameA',0
code_end:

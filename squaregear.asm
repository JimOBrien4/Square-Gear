;

; TO DO:
; -Make pause button handler change -Performance Mode- to -Settings Mode- and vice versa. 
; -Allow user to toggle Setting items
; -Make ScaleBuilder build the scale based on what's written on the screen, include chromatics, update PlayLoop as needed
; -Make setting items actually do things
; -Figure out Sensitivity Off glitch




;==============================================================
; WLA-DX banking setup
;==============================================================
.memorymap
defaultslot 0
slotsize $8000
slot 0 $0000
.endme

.rombankmap
bankstotal 1
banksize $8000
banks 1
.endro

;==============================================================
; SMS defines
;==============================================================
.define VDPControl $bf
.define VDPData $be
.define VRAMWrite $4000
.define CRAMWrite $c000

;==============================================================
; SDSC tag and SMS rom header
;==============================================================
.sdsctag 1.2,"PSG Controller Test","Real-time PSG Controller","Net Nomad"

.bank 0 slot 0
.org $0000
;==============================================================
; Boot section
;==============================================================
    di              ; disable interrupts
    im 1            ; Interrupt mode 1
    jp setup         ; jump to main program



.org $0066
;==============================================================
; Pause button handler
;==============================================================
    ld a,(isPlaying)
    xor $FF
    jp nz,SetPlayingOff
    ld a,$FF
    ld (isPlaying),a
    retn
    SetPlayingOff:
    ld a,$00
    ld (isPlaying),a
    retn

;==============================================================
; Setup
;==============================================================
setup:
    ld sp, $dff0

    ;==============================================================
    ; Set up VDP registers
    ;==============================================================
    ld hl,VDPInitData
    ld b,VDPInitDataEnd-VDPInitData
    ld c,VDPControl
    otir

    ;==============================================================
    ; Clear VRAM
    ;==============================================================
    ; 1. Set VRAM write address to $0000
    ld hl,$0000 | VRAMWrite
    call SetVDPAddress
    ; 2. Output 16KB of zeroes
    ld bc,$4000     ; Counter for 16KB of VRAM
-:  xor a
    out (VDPData),a ; Output to VRAM address, which is auto-incremented after each write
    dec bc
    ld a,b
    or c
    jr nz,-

    ;==============================================================
    ; Load palette
    ;==============================================================
    ; 1. Set VRAM write address to CRAM (palette) address 0
    ld hl,$0000 | CRAMWrite
    call SetVDPAddress
    ; 2. Output colour data
    ld hl,PaletteData
    ld bc,PaletteDataEnd-PaletteData
    call CopyToVDP

    ;==============================================================
    ; Load tiles (font)
    ;==============================================================
    ; 1. Set VRAM write address to tile index 0
    ld hl,$0000 | VRAMWrite
    call SetVDPAddress
    ; 2. Output tile data
    ld hl,FontData              ; Location of tile data
    ld bc,FontDataSize          ; Counter for number of bytes to write
    call CopyToVDP

    ;==============================================================
    ; Write text to name table
    ;==============================================================
    Call PrintScreen

    ; Turn screen on
    ld a,%01100000
;          ||||||`- Zoomed sprites -> 16x16 pixels
;          |||||`-- Doubled sprites -> 2 tiles per sprite, 8x16
;          ||||`--- Mega Drive mode 5 enable
;          |||`---- 30 row/240 line mode
;          ||`----- 28 row/224 line mode
;          |`------ VBlank interrupts
;          `------- Enable display
    out (VDPControl),a
    ld a,$81
    out (VDPControl),a

 jr Input
;==============================================================
; Main loops
;==============================================================
Settings:
    ld a,(isPlaying)
    xor $00
    jr nz,PlayInit
    jr Settings

isPlaying:
.db $FF

PlayInit:
ld hl,$78DA
call SetVDPAddress
ld bc,PlayMode
Call Print
Play:
jr Input
PlayLoop: ;hl = string address, bc = thing to print
    ld hl,$78CC
    call SetVDPAddress
    call Print
    ld a,(isPlaying)
    xor $FF
    jr nz,Settings
    Input:
    in a,($DC) ;get player 1 input
    xor $FD ;is the user pressing only down?
    jr z,Down
    in a,($DC)
    xor $F9 ;is the user pressing down left? etc
    jr z,DownLeft
    in a,($DC)
    xor $FB
    jr z,Left
    in a,($DC)
    xor $FA
    jr z,UpLeft
    in a,($DC)
    xor $FE
    jr z,Up
    in a,($DC)
    xor $F6
    jr z,UpRight
    in a,($DC)
    xor $F7
    jp z,Right
    in a,($DC)
    xor $F5
    jp z,DownRight
    in a,($DC)
    xor $FF ;is there no input?
    jp z,Empty
    jr PlayLoop

Down:
ld bc,NoteC   
ld a,%11010000;full volume in channel 2
out ($7f),a
ld a,%11001011;play C5 in channel 2, low 4 bits
out ($7f),a
ld a,%00011010;high 6 bits
out ($7f),a
jr PlayLoop

DownLeft:
ld bc,NoteD
ld a,%11010000
out ($7f),a
ld a,%11001100
out ($7f),a
ld a,%00010111
out ($7f),a
jp PlayLoop

Left:
ld bc,NoteE
ld a,%11010000
out ($7f),a
ld a,%11000011
out ($7f),a
ld a,%00010101
out ($7f),a
jp PlayLoop

UpLeft:
ld bc,NoteF
ld a,%11010000
out ($7f),a
ld a,%11000000
out ($7f),a
ld a,%00010100
out ($7f),a
jp PlayLoop

Up:
ld bc,NoteG
ld a,%11010000
out ($7f),a
ld a,%11001101
out ($7f),a
ld a,%00010001
out ($7f),a
jp PlayLoop

UpRight:
ld bc,NoteA
ld a,%11010000
out ($7f),a
ld a,%11001110
out ($7f),a
ld a,%00001111
out ($7f),a
jp PlayLoop

Right:
ld bc,NoteB
ld a,%11010000
out ($7f),a
ld a,%11000010
out ($7f),a
ld a,%00001110
out ($7f),a
jp PlayLoop

DownRight:
ld bc,NoteC
ld a,%11010000
out ($7f),a
ld a,%11000101
out ($7f),a
ld a,%00001101
out ($7f),a
jp PlayLoop

Empty:
ld bc,Rest
ld a,%10011111
out ($7f),a
ld a,%11011111
out ($7f),a
ld a,%11111111
out ($7f),a
ld a,%10111111
out ($7f),a;mute channel 2
jp PlayLoop

-:  jr - 

;==============================================================
; Helper functions
;==============================================================

SetVDPAddress:
; Sets the VDP address
; Parameters: hl = address
    push af
        ld a,l
        out (VDPControl),a
        ld a,h
        out (VDPControl),a
    pop af
    ret

CopyToVDP:
; Copies data to the VDP
; Parameters: hl = data address, bc = data length
; Affects: a, hl, bc
-:  ld a,(hl)    ; Get data byte
    out (VDPData),a
    inc hl       ; Point to nt letter
    dec bc
    ld a,b
    or c
    jr nz,-
    ret

 Print: ; Prints ASCII string in SetVDPAddress location. bc = String address. strung MUST end with .db $ff
-:  ld a,(bc)
    cp $ff
    jr z,+
    out (VDPData),a
    xor a
    out (VDPData),a
    inc bc
    jr -
+:
    ret

  PrintScreen:
  ; 1. Set VRAM write address to tilemap index 0
    ld hl,$7812 ;$3800 | VRAMWrite
    call SetVDPAddress
    ; 2. Output tilemap data
    ld bc,Row1
    Call Print

    ld hl,$7848 ;shift to the second row
    call SetVDPAddress
    ld bc,Row2
    Call Print

    ld hl,$78DA
    call SetVDPAddress
    ld bc,PlayMode
   Call Print

    ld hl,$7980
    call SetVDPAddress
    ld bc,Octave
    Call Print

    ld hl,$79A0
    call SetVDPAddress
    ld bc,Sharp
    Call Print

    ld hl,$79C0
    call SetVDPAddress
    ld bc,Half
    Call Print

    ld hl,$79E0
    call SetVDPAddress
    ld bc,Sharp
    Call Print

    ld hl,$7A00
    call SetVDPAddress
    ld bc,Sensativity
    Call Print

    ld hl,$7A20
    call SetVDPAddress
    ld bc,On
    Call Print

    ld hl,$7A40
    call SetVDPAddress
    ld bc,Mode
    Call Print

    ld hl,$7A60
    call SetVDPAddress
    ld bc,Major
    Call Print

    ld hl,$7A80
    call SetVDPAddress
    ld bc,Tonic
    Call Print

    ld hl,$7AA0
    call SetVDPAddress
    ld bc,NoteC
    Call Print
    ret
;==============================================================
; Data
;==============================================================

.asciitable
map " " to "~" = 0
.enda

Row1:
.asc "=SQUARE GEAR="
.db $ff

Row2:
.asc "Real-time PSG Controller"
.db $ff

NoteC:
.asc "C"
.db $ff

NoteD:
.asc "D"
.db $ff

NoteE:
.asc "E"
.db $ff

NoteF:
.asc "F"
.db $ff

NoteG:
.asc "G"
.db $ff

NoteA:
.asc "A"
.db $ff

NoteB:
.asc "B"
.db $ff

Rest:
.asc " "
.db $ff

ErrorMsg:
.asc "Error"
.db $ff

Options:
Sensativity:
.asc " Sensative: "
.db $ff

Half:
.asc " Half-step: "
.db $ff

Octave:
.asc " Octave: "
.db $ff

Mode:
.asc " Mode: "
.db $ff

Tonic:
.asc " Tonic: "
.db $ff

On:
.asc "Y"
.db $ff

Off:
.asc "N"
.db $ff

Sharp:
.asc "#"
.db $FF

Flat:
.asc "b"
.db $FF

Arrow
.asc ">"
.db $FF

Major:
.asc "M"
.db $FF

Minor:
.asc "m"
.db $FF

PlayMode:
.asc "-Performance Mode-"
.db $FF

SettingMode:
.asc "-Settings Mode-"
.db $FF


PaletteData:
;.db $00,$3f ; Black, white
.db $20, $3f ; White, blue
PaletteDataEnd:

; VDP initialisation data
VDPInitData:
.db $04,$80,$00,$81,$ff,$82,$ff,$85,$ff,$86,$ff,$87,$00,$88,$00,$89,$ff,$8a
VDPInitDataEnd:

FontData:
.incbin "font.bin" fsize FontDataSize

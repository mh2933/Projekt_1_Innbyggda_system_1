;
; test_projekt_1_inbyggda.asm
; 
; F�rsta steget blir att f� ig�ng timer 2 toggle funktionen
;
; Created: 2023-02-01 12:28:16
; Author : mh293
;

;MAKRON
.EQU LED1    = PORTB0
.EQU LED2    = PORTB1
.EQU BUTTON1 = PORTB3
.EQU BUTTON2 = PORTB4
.EQU BUTTON3 = PORTB5

;INTERRUPT VEKTORER
.EQU RESET_vect        = 0x00 
.EQU PCINT0_vect       = 0x06
.EQU TIMER2_OVF_vect   = 0x12
.EQU TIMER1_COMPA_vect = 0x16
.EQU TIMER0_OVF_vect   = 0x20

;R�KNARE
.EQU TIMER0_MAX_COUNT = 6
.EQU TIMER1_MAX_COUNT = 12
.EQU TIMER2_MAX_COUNT = 24

;.DEF LED2_REG    = R18 ; CPU-register som lagrar (1 << LED2).

;DATASEGMENT INKL. GLOBALA VARIABLER
.DSEG
.ORG SRAM_START     ; 
  counter0: .byte 1 ; static uint8_t ; f�r timer0
  counter1: .byte 1 ; static uint8_t ; f�r timer1
  counter2: .byte 1 ; static uint8_t ; f�r timer2

;KODSEGMENT
.CSEG

; Vitkigt att avbrottsvektorerna l�ggs i adressordning och att resterande kod l�ggs efter 
.ORG RESET_vect    ; Programmets startsadress
  RJMP main        ; Hoppar till subrutinen main f�r att starta programmet 
.ORG PCINT0_vect   ; if (BUTTON_IS_PRESSED) LED1_TOGGLE;
  RJMP ISR_PCINT0  ; Hoppar till motsvarande avbrottsrutin ISR_PCINT0               
.ORG TIMER2_OVF_vect
  RJMP ISR_TIMER2_OVF
.ORG TIMER1_COMPA_vect
  RJMP ISR_TIMER1_COMPA
.ORG TIMER0_OVF_vect
  RJMP ISR_TIMER0_OVF

ISR_PCINT0:
  ; Debounce-skydd, st�ng av PCIE0 och s�tt p� Timer 0. 
   ; S�tter p� Timer 0 i 300 ms, sedan �teraktiveras avbrott.
  CLR R24
  STS PCICR, R24
  LDI R16, 0x01
 // STS TIMSK0, R16

  LDI R24, ~(1 << PCIE0)
  STS PCICR, R20

  IN R24, PINB
  ANDI R24, (1 << BUTTON1)
  BREQ check_button2  ; om tidigare rad = 0 k�r check_button2
  CALL system_reset   ; annars system_reset 
  RETI
check_button2:
  IN R24, PINB
  ANDI R24, (1 << BUTTON2) 
  BREQ check_button3
  RCALL timer1_toggle
  RETI
check_button3:
  IN R24, PINB
  ANDI R24, (1 << BUTTON3) 
  BREQ ISR_PCINT0_end
  RCALL timer2_toggle
ISR_PCINT0_end:
  RETI


ISR_TIMER0_OVF:
  LDS R24, counter0
  INC R24
  CPI R24, TIMER0_MAX_COUNT
  BRLO ISR_TIMER0_OVF_end
  STS PCICR, R16
  CLR R24
  STS TIMSK0, R24
ISR_TIMER0_OVF_end:
  STS counter0, R24
  RETI

ISR_TIMER1_COMPA:       ; ISR rutinen kan ligga i vilken ordning som helst
  LDS R24, counter1     ; l�ser in v�rdet f�r timer1_counter.
  INC R24               ; R�knar upp. 
  CPI R24, TIMER1_MAX_COUNT ; J�mf�r antalet avbrott med heltalet 12
  BRLO ISR_TIMER1_COMPA_end         ; om mindre en 12 avbrott avsluta avb.rutin
  LDI R16, (1 << LED1)
  OUT PINB, R16            ; Togglar LED1.
  CLR R24          ; Nollst�ller r�knaren inf�r n�sta uppr. 
ISR_TIMER1_COMPA_end:
  STS counter1, R24 ; skriver det uppdaterade v�rdet p� timer0_c. 
  RETI           ; Avslutar avbrottsrutinen, �terst�ller CPU-register mm.

ISR_TIMER2_OVF:
  LDS R24, counter2
  INC R24
  CPI R24, TIMER2_MAX_COUNT ; kollar om de f�reg�ende v�rdet �r lika med
  BRLO ISR_TIMER2_OVF_end   ; branch if lower
  LDI R16, (1 << LED2)
  OUT PINB, R16            ; Togglar LED2.
  CLR R24
ISR_TIMER2_OVF_end: 
  STS counter2, R24
  RETI

main:

init_ports:
  LDI R16, (1 << LED1) | (1 << LED2)
  OUT DDRB, R16
  LDI R17, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)
  OUT PORTB, R17
  SEI

init_interrupts:
  LDI R20, (1 << PCIE0) ; laddar bit 0 till R20 
  STS PCICR, R20        ; R20 sparas i destination PCICR i dataminnet, och aktiverar PCI avbrott  p� I/O port B 
  STS PCMSK0, R17 ; aktiverar avbrott p� tryckknappens pin 
  LDI R18, (1 << CS20) | (1 << CS21) | (1 << CS22) ; prescaler 1024
  STS TCCR2B, R18 ; OUT TCCR2B, R18 ; Operand 1 out of range: 0xb1
  
init_timer1:
  LDI R16, (1 << CS12) | (1 << CS10) | (1 << WGM12) ; prescaler 1024
  STS TCCR1B, R16                    ; Aktiverar Timer 1 i CTC mode
  ; OCR1A = 256                      ; 0000 0001 0000 0000
  LDI R17, 0x01                      ; Lagrar 0000 0001 i R17 high bit
  LDI R16, 0x00                      ; Lagrar 0000 0000 i R16 low bit
  STS OCR1AH, R17                    ; Tilldelar 256 till OCR1A high bit
  STS OCR1AL, R16                    ; Tilldelas 256 low bit 
  LDI R16, (1 << CS00) | (1 << CS02)
  OUT TCCR0B, R16

main_loop:
  RJMP main_loop

system_reset:
   ; Sl�ck leds, st�nga av timers och nollst�ll r�knarna.
   IN R24, PORTB
   ANDI R24, ~((1 << LED1) | (1 << LED2))
   OUT PORTB, R24

   CLR R24
   STS counter0, R24
   STS counter1, R24
   STS counter2, R24

   STS TIMSK1, R24
   STS TIMSK2, R24

   RETI

timer1_toggle:
  LDS R24, TIMSK1
  ANDI R24, (1 << OCIE1A)
  BREQ timer1_on
timer1_off:
  CLR R24
  STS TIMSK1, R24 ; Timer 1 av.
  IN R24, PORTB
  ANDI R24, ~(1 << LED1)
  OUT PORTB, R24
  RET
timer1_on: ;S�tter ig�ng timer1 som t�nder led1
  LDI R24, (1 << OCIE1A)
  STS TIMSK1, R24  ; (1 << OCIE1A) = (1 << LED2) = R17
  RET

timer2_toggle:
  LDS R24, TIMSK2
  ANDI R24, (1 << TOIE2)
  BREQ timer2_toggle_enable
timer2_toggle_disable:
  IN R24, PORTB
  ANDI R24, ~(1 << LED2) ; Led 2 av.
  OUT PORTB, R24
  CLR R24
  STS TIMSK2, R24 ; Timer 2 av.
  RET
timer2_toggle_enable:
  LDI R24, (1 << TOIE2)
  STS TIMSK2, R24
  RET



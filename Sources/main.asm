;*******************************************************************
;Universidad Nacional de Colombia - Facultad de Ingenieria
;Departamento de Ingenieria Mecanica y Mecatronica
;Microcontroladores
;2019-1
;Laboratorio 4 - Ascensor 
;Estudiantes:
;				Juan Diego Bencardino Perdomo
;				Jhon Esteban Luengas Machado                                       *
;*******************************************************************

; Include derivative-specific definitions
            INCLUDE 'derivative.inc'
            

; export symbols
            XDEF _Startup, main, IRQ_ISR, KBI_ISR, RTI_ISR
            ; we export both '_Startup' and 'main' as symbols. Either can
            ; be referenced in the linker .prm file or from C/C++ later on
            
            
            
            XREF __SEG_END_SSTACK   ; symbol defined by the linker for the end of the stack

; Constants section
ROM_VAR: SECTION
pisos:   dc.b  $01,$02,$03,$04

; variable/data section
MY_ZEROPAGE: SECTION  SHORT         ; Insert here your data definition
actual:  ds.b  1

; code section
MyCode:     SECTION

; ----------------------------------------
; Interrupts Configurations
; ----------------------------------------

irq_cfg:                            ; IRQ configuration
			mov   #%00010010,IRQSC  ; pull resistance enabled, pin enabled,
			                        ; inturrupt enabled, falling edge only
			RTS
			
kbi_cfg:                            ; KBI configuration
            mov   #%00001010,KBISC  ; KBI enabled
                                    ; detect edge only
            mov   #%00000011,KBIPE  ; Pins 1 and 0 enabled for kbi
            mov   #%00000011,KBIES  ; Rising edge/high level for 1 downto 0
            
            RTS
            
rti_cfg:                            ; RTI configuration
			lda   #%00000111
			sta   SRTISC            ; RTI disabled, internal clk,
			                        ; set period to 1024s       
			RTS
			
; ----------------------------------------
; Main code
; ----------------------------------------			     
;
main:
_Startup:
            LDHX  #__SEG_END_SSTACK ; initialize the stack pointer
            TXS
            
            LDA   #$02
            STA   SOPT1             ; Disable watchdog
            
            MOV   #$FF, PTBDD       ; Poner todos los pines de B como salida
                                    ; 3 para el 7447 (D siempre a tierra) (0,1,2),
                                    ; 1 para el buzzer (3) y
                                    ; 4 para los leds (4,5,6,7)
            MOV   #$00, PTBD        ; Iniciar todos los pines en 0
            
            lda   #$FF
            sta   PTAPE             ; Enable pull-up en todos los pines de A
            
            JSR   irq_cfg           ; ir a configuración de irq
            JSR   kbi_cfg           ; ir a config kbi
            JSR   rti_cfg           ; ir a config rti
            
			CLI			            ; enable interrupts
			
			mov   #$00,actual       ; inicializar en el primer piso
			CLRH                    ; limpiar H y X
			CLRX                    ; para poder usarlos en el ascensor

mainLoop:
            ; Insert your code here
            NOP
            NOP
            NOP
            
            BRA    mainLoop

; ----------------------------------------
; Interrupciones
; ----------------------------------------

; Rutina de servicio de interrupción IRQ
IRQ_ISR:
            bset  2,IRQSC
            LDA   PTBD
            EOR   #$01
            STA   PTBD
            RTI
; Fin de interrupción por IRQ

; Rutina de servicio de interrupción KBI
KBI_ISR:
            ldx   actual            
            brclr 0,PTAD,bajar      ;preguntar qué botón fue presionado
            brclr 0,PTAD,subir
            bset  2,KBISC           ;limpiar bandera al poner en 1 el bit, acknowledge interrupcion
                                    ;para permitir alguna interrupción futura
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion
bajar:
            CBEQX #$00,vueltab
            inc   X
                       
            bset  2,KBISC           ;limpiar bandera al poner en 1 el bit, acknowledge interrupcion
                                    ;para permitir alguna interrupción futura
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion
vueltab:
            
            bset  2,KBISC           ;limpiar bandera al poner en 1 el bit, acknowledge interrupcion
                                    ;para permitir alguna interrupción futura
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion         
subir:      
            bset  2,KBISC           ;limpiar bandera al poner en 1 el bit, acknowledge interrupcion
                                    ;para permitir alguna interrupción futura
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion

; Fin de interrupción por KBI

; Rutina de servicio de interrupción RTI
RTI_ISR:
            lda   #%01000000        ;limpiar bandera al poner en 1 el bit, acknowledge interrupcion
            ora   SRTISC            ;para permitir la siguiente interrupción ya que es periódica
            sta   SRTISC
            lda   #%00001000
            eor   PTBD              ;alternar estado de pin
            sta   PTBD
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion	
; Fin de interrupción por RTI	
	

; ----------------------------------------
; Subrutinas para acciones
; ----------------------------------------

retardo:                      ; se busca un retardo de 1s teniendo una frecuencia de 4Mhz en el bus
            lda   #$10        ;cargar 0x10 en acumuladorm, dir immediata
rt0:		
			psha              ;dir inherente, push lo del acumulador al stack
			lda   #$ff        ;dir immediata, cargar el acumulador con 255

rt1:
            psha              ;push lo del acumulador en el stack
            lda   #$ff        ;;cargar 0xff en acumulador
rt2:
            dbnza rt2         ;decrement Acumulador, branch a etiqueta rt2 if not zero, dir directa
            pula              ;sacar lo del stack y ponerlo en el acumulador, dir inherente
            dbnza rt1         ;decrement Acumulador, branch a etiqueta rt1 if not zero, dir directa
            pula              ;sacar lo del stack y ponerlo en el acumulador, dir inherente
            dbnza rt0         ;para salir de este condicional se tuvieron que hacer aproximadamente 4*256*256*17
            rts               ;return from subroutine, volver a desde donde se llamo la subrutina

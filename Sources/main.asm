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
pisos:   dc.b  1,2,3,4
		; POS X 00  01  02  03  
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
            mov   #%00000000,KBIES  ; Falling edge/low level
            						; Es necesario dejarlo en flanco de subida, debido a que
            						; los puertos en A fueron configurados en pull-up (detecta)
            						; flanco de bajada
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
            
            MOV   #%11111111, PTBDD       ; Poner todos los pines de B como salida
                                    ; 3 para el 7447 (D siempre a tierra) (0,1,2),
                                    ; 1 para el buzzer (3) y
                                    ; 4 para los leds (4,5,6,7)
            MOV   #%10000100, PTBD  ; Inicia en piso 4 (led,display)
            MOV   #%00000100, PTADD ; PTA2 es la unica salida (Buzzer)
            MOV   #%00000000, PTAD  ; Solo pone en cero PTA2, los demas los ignora

            lda   #%11111111		; carga 0xFF en el acumulador
            sta   PTAPE             ; Enable pull-up en todos los pines de A (FF del acumulador)
            
			CLI			            ; enable interrupts
			
			mov   #%00000011,actual ; inicializar en el piso 4 (3+1)
	;		CLRH                    ; limpiar H y X
			CLRX                    ; para poder usarlos en el ascensor
            JSR   irq_cfg           ; ir a configuración de irq
            JSR   kbi_cfg           ; ir a config kbi
            JSR   rti_cfg           ; ir a config rti			

mainLoop:
			;BRSET 7, SRTISC,RTI_ISR
			;BRSET 3, IRQSC,IRQ_ISR
			;BRSET 3, KBISC,KBI_ISR
			nop
			nop
			nop
			
			       
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
			CLRX
			CLRH
            bset  2,KBISC           ;limpiar bandera al poner en 1 el bit, acknowledge interrupcion
                       				;para permitir alguna interrupción futura
            ldx   actual            
            brclr 1,PTAD,bajar      ;preguntar qué botón fue presionado
            brclr 0,PTAD,subir
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion
bajar:
            CBEQX #$00,vueltab
            decX
            lda   PTBD
            AND   #$F0 				; Deja intacto los bits de los LEDS, 
            ADD	  pisos,X
            STA   PTBD
            STX	  actual
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion
vueltab:
			ldx   #$03
			lda   PTBD
            AND   #$F0
            ORA	  pisos,X
            STA   PTBD
            bset  2,KBISC           ;limpiar bandera al poner en 1 el bit, acknowledge interrupcion
                                    ;para permitir alguna interrupción futura
            LDX   actual                      
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion                           
subir:      
			CBEQX #$03,vueltaa
            incx
            lda   PTBD
            AND   #$F0
            ADD	  pisos,X
            STA   PTBD
            LDX actual
            rti                     ;return from interrupt, retomar el punto desde donde
                                    ;se activo la interrupcion
                                
vueltaa:
            ldx   #$00
                                    ;para permitir alguna interrupción futura
			lda   PTBD
            AND   #$F0
            ORA	  pisos,X
            STA   PTBD
            bset  2,KBISC           ;limpiar bandera al poner en 1 el bit, acknowledge interrupcion
                                    ;para permitir alguna interrupción futura
            LDX actual                      
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

;***************************************************************************

      nolist
      include 'ioequ.asm'
      include 'intequ.asm'
      include 'ada_equ.asm'
      include 'vectors.asm'  
	list
  
;******************************************************************************
;					CONSTANTES
buffer_size equ	1024 ; tamaño de la ventana en muestras

Left_ch			equ	0

flag_proc_1	equ  0				; flag bits para marcar el estado de procesamiento
flag_proc_2   equ  (flag_proc_1+1)
; Control word for CS4218
CTRL_WD_12      equ     MIN_LEFT_ATTN+MIN_RIGHT_ATTN+LIN2+RIN2
CTRL_WD_34      equ     MIN_LEFT_GAIN+MIN_RIGHT_GAIN

;******************************************************************************
       org    x:$0

channel_sync	ds	1
proc_flag_mem	ds	 1
buff1_R	ds	 1
buff2_R	ds	 1
	
buffer_1	dsm	3*buffer_size ; reservo espacio para buffer 1 de in, out, y procesamiento
buffer_2	dsm	3*buffer_size ; reservo espacio para buffer 1 de in, out, y procesamiento

	org	y:$0
	
    include 'window.txt'  


        org     p:$100
START
main
        movep   #$040006,x:M_PCTL  ; PLL 7 X 12.288 = 86.016MHz
        ori     #3,mr                 ; mask interrupts
        movec   #0,sp              ; clear hardware stack pointer
        move    #0,omr            ; operating mode 0

;==================

	move    #0,X0
	move    X0,x:channel_sync
	
;========================================
;                                   INICIALIZACION 
        jsr     ada_init           ; initialize codec
		move 	#buffer_size*3,M1	 ; cargo R1, M1 y N1. 
		move	#buffer_1,R1   
		move	#buffer_size,N1
		
		move 	#buffer_size*3,M2	 ; cargo R2, M2 y N2.
		move	#(buffer_2+buffer_size/2),R2   ; le fijo un offset de medio buffer para el Overlap
		move	#buffer_size,N2
		
		bclr	#flag_proc_1,x:proc_flag_mem	; empieza el programa sin datos para procesar
		bclr	#flag_proc_2,x:proc_flag_mem	; empieza el programa sin datos para procesar
		
;========================================
 
pipe_loop

	brset    #flag_proc_1,x:proc_flag_mem,procesar_1         ; branch if bit is set
	brset   #flag_proc_2,x:proc_flag_mem,procesar_2         ; branch if bit is set
	jmp		pipe_loop		; if there are no new buffers, keep waiting
	
procesar_1	move	R1,X0   ;ojo quizas haya que cargar r1 y n1 de memoria
					move	X0,A    
					move	N1,X1
					sub		X1,A
					nop
					move	A,X0
					move	X0,r0
					jmp	start_win		
					
procesar_2	move	R2,X0   ;ojo quizas haya que cargar r2 y n2 de memoria
					move	X0,A    
					move	N2,X1
					sub		X1,A
					nop
					move	A,X0
					move	X0,r0

;============================================================================
;	                 ANALYSIS   W I N D O W
;============================================================================   
;r0-> data    X
;r4=> window	Y
start_win	move   #an_win_base,r4
		clr		A
		nop 
		nop
		move       x:(r0)+,x0	y:(r4)+,y0    ; Read data  and  first window sample
		
		do		#buffer_size-1,w_loop
		mpy        x0,y0,A	x:(r0),x0	   y:(r4)+,y0 ; multiply samples
		nop	;pipeline shit
		nop
w_loop		move	A,x:(r0)+
		

;=========================FIN ANALYSIS WINDOW====================================



	jmp     pipe_loop	;go back to waiting state

;====================================
right_channel_sr	nop

		move 	#buffer_size*3,M1	 ; cargo R1, M1 y N1. 
		move	x:buff1_R,R1   
		move	#buffer_size,N1
		
		move 	#buffer_size*3,M2	 ; cargo R2, M2 y N2.
		move	x:buff2_R,R2   
		move	#buffer_size,N2

		move	X0,x:(R1)  ; send sample to In buffer1
		nop		;avoid pipeline stall
		move	X0,x:(R2)  ; send sample to In buffer2
		
;get samples from out buffers and sum them
		move	x:(R1+N1),X0
		move	x:(R2+N2),X1
		move	X0,A		
		add	    X1,A		(R2)+	; get sum and update R2
		move	x:(R1)+,X1		; no sirve de nada cargar X1, avoid pipeline stall and update R1
		move	A,X0	 		; put it in X0 to send it to DAC
		
		move	R2,x:buff2_R 	;save R1,R2 for next interruption
		move	R1,x:buff1_R   
		
					rts
;====================================
 
left_channel_sr 	nop	;send ad to dac
					rts

		include 'ada_init.asm'	; used to include codec initialization routines
		
		include 'interrupts.asm'	; ISRs

        end


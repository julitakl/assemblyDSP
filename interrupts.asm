;****************************************************************************
;	SSI0_ISR.ASM    Ver.2.0
;	Example program to handle interrupts through
;       the 56307 SSI0 to move audio through the CS4218
;
;       Copyright (c) MOTOROLA 1995, 1996, 1997, 1998
;		      Semiconductor Products Sector 
;		      Digital Signal Processing Division
;
;
;       History:
;               	14 June 1996: RLR/LJD - ver 1.0
;			23 July 1997: BEA     - ver 1.1
;			1  june 2001: Dany
;			24 Dec  2010: Andres
;******************************************************************************


;----the actual interrupt service routines (ISRs)  follow:

;************************ SSI TRANSMIT ISR *********************************
ssi_txe_isr
        bclr    #4,x:M_SSISR0           ; Read SSISR to clear exception flag
                                        ; explicitly clears underrun flag
ssi_tx_isr

	rti
	
 

;********************* SSI TRANSMIT LAST SLOT ISR **************************
ssi_txls_isr
        rti

;************************** SSI receive ISR ********************************
ssi_rxe_isr
        bclr    #5,x:M_SSISR0           ; Read SSISR to clear exception flag
                                        ; explicitly clears overrun flag
ssi_rx_isr
	
        movep   x:M_RX0,x0         		; Read a/d data
		brclr    #Left_ch,X:channel_sync,right_ch        
	
left_ch	
		; process left channel
		bchg	#Left_ch,X:channel_sync
		jsr		left_channel_sr

		bra		endisr
		
right_ch
		; process right channel
		bchg	#Left_ch,X:channel_sync
		jsr		right_channel_sr
		
endisr	movep	x0,x:M_TX00				; Write d/a
		rti



;********************** SSI receive last slot ISR **************************
ssi_rxls_isr
		bset	#Left_ch,x:channel_sync
        rti

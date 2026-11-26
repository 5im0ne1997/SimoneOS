bits 16 ; Genera codice per CPU in modalita' 16 bit
org 0x7C00 ; Calcola gli indirizzi delle etichette partendo da 0x7C00, altrimenti inizierebbe a contare da 0 e andrebbero fuori dalla nostra sezione di memoria
cli ; Clear Interrupt Flag, disabilita gli interrupt mascherabili impostando IF = 0, la CPU ingora questi interrupt
TornaAHlt: hlt ; mette la CPU in hlt fino al possimo intterrupt, in questo caso un interrupt non mascherabile. Dopo il risveglio, esegue jmp verso questa istruzione e la CPU torna in hlt
jmp TornaAHlt ; salta all'istruzione con etichetta TornaAHlt, quindi all'istruzione precedente
times 510-($-$$) db 0x00 ; Riempie di 0x00 per N volte. $ vale quanto la riga corrente (in questo caso 0x7C04, le prime due righe valgono solo per l'assembler, non sono istruzioni scritte nel file risultante) e $$ l'indirizzo della prima istruzione (quindi 0x7C00) 
dw 0xAA55 ; aggiunge la firma di boot

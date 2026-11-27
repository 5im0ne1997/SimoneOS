bits 16 ; Genera codice per CPU in modalita' 16 bit
org 0x7C00 ; Calcola gli indirizzi delle etichette partendo da 0x7C00, altrimenti inizierebbe a contare da 0 e andrebbero fuori dalla nostra sezione di memoria
jmp 0x0000:ScriviS ; far jump per impostare CS = 0
ScriviS:
  cli
  mov ax, 0 ; imposto il registro AX a 0. Questo perchè DS è un registro di segmento e non posso impostarlo direttamente ma devo copiare il valore da un registro generico come AX
  mov ds, ax
  mov es, ax
  mov ss, ax
  mov sp, 0x7C00 ; SP è generico quindi posso farlo
  cld ; Clear Direction Flag, imposta la direzione per leggere una stringa da sinistra a destra, con std viene letta al contrario
  sti ; Ripristina gli interrupt mascherabili, li riattivo dopo aver impostato SS e SP per evitare che vengano eseguiti nel frattempo
  mov ah, 0x0E ; sceglie la funzione video per stampare contenuto in AL a schermo
  mov al, 'S' ; carattere da stampare a video in codice ASCII
  mov bh, 0 ; usa la prima pagina video
  int 0x10 ; richiama il servizio BIOS di gestione video teletype usando un interrupt software, la stampa nella pagina 0 il carattere 'S'. 
cli ; Clear Interrupt Flag, disabilita gli interrupt mascherabili impostando IF = 0, la CPU ignora questi interrupt
TornaAHlt: 
  hlt ; mette la CPU in hlt fino al prossimo interrupt, in questo caso un interrupt non mascherabile. Dopo il risveglio, esegue jmp verso questa istruzione e la CPU torna in hlt
jmp TornaAHlt ; salta all'istruzione con etichetta TornaAHlt, quindi all'istruzione precedente
times 510-($-$$) db 0x00 ; Riempie di 0x00 per N volte. $ vale quanto la riga corrente e $$ l'indirizzo della prima istruzione 
dw 0xAA55 ; aggiunge la firma di boot

# SimoneOS

Il seguente progetto serve per studiare il funzionamento di un computer partendo dalle basi. L'obbiettivo è riscrivere da zero un intero sistema operativo.

## Lezione 1 - Dall'accensione alla prima esecuzione.

### 1 - Come funziona un PC

Un computer è un insieme di componenti che lavorano e comunicano tra di loro per eseguire istruzioni e compiti. Il vero cuore di tutto è il processore (CPU) e la memoria.

La **memoria** è un array di byte, ad ogni byte viene assegnato un numero progressivo, il suo **indirizzo**. Ogni byte è composto da 8 bit, di conseguenza ogni byte può contenere un valore compreso tra 0 e 255. All'interno di ogni byte non esistono tipi, variabili o file, ma il valore che esso rappresenta.  
La CPU elabora i dati contenuti nella memoria a ciclo continuo:

1. Legge dalla memeoria i dati contenuti nell'indirizzo indicato all'interno dell'**Instrution Pointer** (IP), è un indirizzo speciale che indica alla CPU in quale indirizzo deve prendere il contenuto della memoria.
2. Interpreta i dati prelevati dalla memoria nel dato indirizzo come una istruzione. Il byte `F4` per una CPU x86 significa 'fermati' (`hlt`).
3. Esegue l'istruzione e sposta IP sull'istruzione successiva.

#### I registri

Dentro una CPU esistono delle celle di memoria molto veloci, i **registri**. In modalità 16 bit (più avanti verrà spiegato perché si parte da 16 bit) i registri principali sono:

| Registro | Nome | Uso tipico |
--------------------------------
| AX, BX, CX, DX | Accumulator, Base, Counter, Data | Di uso generale |
| SI, DI | Source Index, Destination Index | Copie di blocchi di memoria |
| SP, BP | Stack Pointer, Base Pointer | Lo stack (spiegato più avanti) |
| IP | Instruction Pointer | La prossima istruzione da eseguire |
| CS, DS, ES, SS | Code, Data, Extra, Stack Segment | Selezionano le zone di memoria |
| FLAGS |   | Bit di stato: risultato zero, riporto, segno... |

#### Perché si usa l'esadecimale

Un byte è composto da 8 bit. Una cifra in esadecimale rappresenta 4 bit, quindi un bite si può rappresentare sempre con 2 cifre esadecimali:

```
binario 1111 0100
hex        F    4 -> 0xF4 (244 in decimale)
```

La transalzione da binario a esadecimale e vice versa è semplice, in esadecimale quindi si possono rappresentare lo stesso dato con meno caratteri, di conseguenza è più facile scriverlo. Il prefisso `0x` serve a rappresentare che il numero è un esadecimale.

#### Linguaggio macchina, Assembly e C

Il Linguaggio macchina sono i byte che la CPU esegue, per esempio `F4`. Per semplificare la scrittura delle istruzioni, viene in aiuto l'Assembly. È un linguaggio di basso livello che traduce i byte della CPU in un linguaggio leggibile agli umani, per esempio `F4` viene rappresentato come `hlt`. L'Assembler (per esempio NASM) traduce queste iscruzioni in linguaggio macchina quasi 1 a 1. Il linguaggio C, invece, è un linguaggio ad alto livello in quanto astrae il concetto di linguaggio macchina ad un livello superiore. Ogni istruzione in C rappresenta numerose istruzioni in Assembly, che a sua volta rappresentano le istruzioni in linguaggio macchina.

### 2 - Il reset, la prima istruzione

Una volta premuto il pulsante di accensione, dopo che l'alimentazione diventa stabile, viene passato alla CPU il segnale di **RESET**. In questo momento ogni registro della CPU sono in uno stato ben preciso, tra questi troviamo:

- CS = 0xF000 con base nascosta 0xFFFF0000
- IP = 0xFFF0

> Ogni registro di segmento ha una parte visibile (il selettore, 16 bit) e una parte nascosta che contiene base, limite e attributi del segmento. La CPU calcola sempre gli indirizzi come base + offset, usando la base nascosta.
>
> Quello che cambia tra le modalità è come viene riempita la parte nascosta quando si carica il registro:
>
> Modalità reale: base = segmento × 16. Così, con registri a 16 bit, si possono indirizzare 20 bit (1 MB).
> Modalità protetta: il selettore è un indice nella GDT/LDT. La CPU legge il descrittore una sola volta e ne copia base, limite e attributi nella parte nascosta, per non dover rileggere la tabella a ogni accesso.
>
> Al reset fa eccezione: CS = 0xF000 ma la base nascosta è impostata direttamente a 0xFFFF0000. Con IP = 0xFFF0 la prima istruzione si trova quindi a 0xFFFFFFF0 (reset vector). Al primo far jump CS viene ricaricato e la base torna a seguire la regola segmento × 16.

Quindi la CPU legge l'istruzione all'indirizzo 0xFFFFFFF0, cioè 16 byte sotto a 4GB. Questo indirizzo si chiama **reset vector**.  
A quell'indirizzo non si trova la RAM, la scheda madre fa in modo che risponda il chipset del firmware (il BIOS o UEFI).

### 3 - Il BIOS: POST e servizi

Una volta che parte il BIOS, esegue in ordine:

1. POST (Power-On Self Test): inizializza il controller della RAM, verifica la CPU, enumera i bus PCI, trova tutti i dischi collegati, periferiche e inizializza le periferiche con una ROM propria
.
2. Prepara i servizi: il BIOS mette in memoria delle funzioni che tutti posso chiamare tramite **interrupt software**:
   - INT 0x10: video (scrivere caratteri, cambiare modalità)
   - INT 0x13: disco (leggere settori)
   - INT 0x16: tastiera
   
   Possiamo definirlo un sistema operativo minimale, serve per poter mostrare a schermo e interagire con le prime fasi dell'accensione.

3. Cerca un dispositivo di avvio seguendo il *boot order* salvato nel BIOS.

### 4 - La modalità reale e l'indirizzamento segmento:offset

Per retrocompatibilità con il processore 8086, ogni CPU x86 moderna parte di modalità reale.

In questa modalità i registri sono a 16 bit (0xF000), quindi un registro arriva fino a 64 KiB.  
Il processore 8086 poteva gestire fino a 1 Mib di memoria, per ovviare a questa cosa veniva moltiplicato il numero del settore per 16, quindi 0xF0000 (20 bit) e veniva aggiunto un offset per raggiungere l'indirizzo di memoria corretto.

La formula quindi è:

`fisico = segmento * 16 + offset`

La base quindi sarebbe `segmento * 16`, quindi significa spostare il segmento di una cifra esadecimale verso sinistra. Quindi:

- 0x07C0 * 16 = 0x07C00
- 0x0000 * 16 = 0x00000

Di conseguenza si possono scrivere gli stessi indirizzi fisici in più modi:

- 0x07C0:0x0000 = 0x07C0 * 16 + 0x0000 = 0x07C00 + 0x0000 = 0x07C00
- 0x0000:0x7C00 = 0x0000 * 16 + 0x7C00 = 0x00000 + 0x7C00 = 0x07C00

Durante il real mode, quindi, CS = 0xF000 dovrebbe dare come base 0xF0000. Invece, subito dopo il RESET, da come base 0xFFFF0000, finché il primo salto lungo (long jump) non riporta la base a seguire le regole normali. È una eccezione della primissima fase del boot.

Una volta che il BIOS passa il controllo alla fase successiva, la memoria di 1 MiB è strutturata così:

0x00000 - 0x003FF   IVT: tabella dei vettori di interrupt (dove sono le funzioni INT)
0x00400 - 0x004FF   BDA: dati del BIOS
0x00500 - 0x07BFF   libera
0x07C00 - 0x07DFF   <- IL NOSTRO SETTORE DI BOOT (512 byte)
0x07E00 - 0x7FFFF   libera
0x80000 - 0x9FFFF   in parte usata dal BIOS (EBDA)
0xA0000 - 0xBFFFF   memoria video <- scriverci = disegnare sullo schermo
0xC0000 - 0xFFFFF   ROM: BIOS video, BIOS di sistema

### 5 - Il settore di BOOT

Per ogni dispositivo all'interno della lista di avvio, il BIOS esegue:

1. Legge il primo settore del disco (LBA 0, 512 byte) e lo copia nell'indirizzo di memoria 0x07C00.
2. Controlla gli ultimi due byte del settore ( offset 510 e 511), devono essere rispettivamente 0x55 e 0xAA. È la firma di boot, se mancano, il BIOS passa al disco successivo.
3. Quando trova la firma, mette nel registro DL il numero del disco e salta a 0x7C00.

Da questo momento la CPU esegue il codice scritto nel disco e si ha pieno potere del computer. Questo settore si chiama MBR (Master Boot Record), dentro si trova il boot loader e la tabella delle partizioni del disco.

### Esercizio 1

Scrivere questo readme

### Esercizio 2

Vedere il comando di RESET.

Con il comando `qemu-system-i386 -S -monitor stdio` viene accesa una macchina virtuale in pausa (subito dopo il comando di RESET) e apre una console su cui poter scrivere i comandi alla CPU.  
Scrivendo il comando `info registers` si possono vedere i registri della CPU e il loro valore. Il risultato è:

```
CPU#0
EAX=00000000 EBX=00000000 ECX=00000000 EDX=00000663
ESI=00000000 EDI=00000000 EBP=00000000 ESP=00000000
EIP=0000fff0 EFL=00000002 [-------] CPL=0 II=0 A20=1 SMM=0 HLT=0
ES =0000 00000000 0000ffff 00009300
CS =f000 ffff0000 0000ffff 00009b00
SS =0000 00000000 0000ffff 00009300
DS =0000 00000000 0000ffff 00009300
FS =0000 00000000 0000ffff 00009300
GS =0000 00000000 0000ffff 00009300
LDT=0000 00000000 0000ffff 00008200
TR =0000 00000000 0000ffff 00008b00
GDT=     00000000 0000ffff
IDT=     00000000 0000ffff
CR0=60000010 CR2=00000000 CR3=00000000 CR4=00000000
DR0=00000000 DR1=00000000 DR2=00000000 DR3=00000000 
DR6=ffff0ff0 DR7=00000400
EFER=0000000000000000
FCW=037f FSW=0000 [ST=0] FTW=00 MXCSR=00001f80
FPR0=0000000000000000 0000 FPR1=0000000000000000 0000
FPR2=0000000000000000 0000 FPR3=0000000000000000 0000
FPR4=0000000000000000 0000 FPR5=0000000000000000 0000
FPR6=0000000000000000 0000 FPR7=0000000000000000 0000
XMM00=0000000000000000 0000000000000000 XMM01=0000000000000000 0000000000000000
XMM02=0000000000000000 0000000000000000 XMM03=0000000000000000 0000000000000000
XMM04=0000000000000000 0000000000000000 XMM05=0000000000000000 0000000000000000
XMM06=0000000000000000 0000000000000000 XMM07=0000000000000000 0000000000000000
```

Possiamo quindi vedere che:

- CS è uguale a f000 ffff0000
- EIP è uguale a 0000fff0

Quindi corrisponde a quello che è stato detto in precedenza, CS è impostato come 0xFFF0 ma la base nascosta è 0xFFFF0000 e l'offset EIP è 0xFFF0.

Provando a leggere il contenuto dell'indirizzo 0xFFFFFFF0 possiamo vedere le istruzioni del BIOS con il comando `xp /16xb 0xfffffff0`. Il Risultato è:

```
00000000fffffff0: 0xea 0x5b 0xe0 0x00 0xf0 0x30 0x36 0x2f
00000000fffffff8: 0x32 0x33 0x2f 0x39 0x39 0x00 0xfc 0x00
```

i byte che ci interessano sono i primi 5.

- 0xea - è un jump far, dice alla CPU di andare a leggere le istruzioni al segmento:offset indicato nei 4 byte successivi. Essendo una CPU Little Endian, a sinistra troveremo i byte meno significativi, quindi vanno letti al contrario.
- 0x5b e 0xe0 - è l'offset 0xe05b
- 0x00 e 0xf0 - è il segmento 0xf000

Quindi l'istruzione dice alla CPU `jmp 0xf000:0xe05b`, facendo il calcolo (dopo il jump far quindi con la regola per * 16): 0xF000 * 16 + 0xE05B = 0xF0000 + 0xE05B = 0xFE05B.

Gli altri byte, dal sesto in poi, sono la data di creazione del BIOS e il tipo di computer. In questo caso sarebbe `06/23/99 IBM PC/AT`, il tipo di computer è il penultimo carattere 0xfc che rappresenta il PC della IBM, l'ultimo è solo un riempitivo.

### Esercizio 3

Far partire la vm con un disco non bootabile

Creo un disco da 512 byte con `dd if=/dev/zero of=./disk.img bs=512 count=1`, poi eseguo `qemu-system-i386 -drive format=raw,file=disk.img`. Possiamo vedere che la vm parte, passa al BIOS che non trova nessun disco con una partizione bootabile, tenta altre sorgenti e infine si ferma. Questo succede perché manca la firma di boot 0xAA55.

### Esercizio 4

Firmare il disco.

Con `printf "\x55\xAA" | dd of=disk.img bs=1 seek=510 conv=notrunc` aggiungo i byte 0x55 e 0xAA in fondo al disco. Con il comando `xxd disk.img` si può vedere il contenuto:

```
00000000: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000010: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000030: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000040: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000050: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000060: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000070: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000080: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000090: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000c0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000d0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000e0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000f0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000100: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000110: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000120: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000130: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000140: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000150: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000160: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000170: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000180: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000190: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001c0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001d0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001e0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001f0: 0000 0000 0000 0000 0000 0000 0000 55aa  ..............U.
```

In questo modo il BIOS vede che è un disco di boot. Copia il contenuto all'indirizzo 0x7C00, poi fa un jump long a 0x7C00, CS si resetta a 0x0000.  
Da questo momento la CPU esegue il codice scritto dentro al disco. Essendo che dentro è una lista di 0x00 e la firma in fondo, esegue il contenuto ma senza fare nulla di particolare in quanto non gli stiamo dicendo di fare nulla.  
Una volta che IP arriva a 0xFFFF, ricomincia da capo e setta IP=0x0000, essendo CS=0x0000, la CPU esegue il codice dentro alla tabella dei vettori IVT all'inizio della memoria.  

Quello che succede è questo:

- esegue in 0x0000 il byte 0x55, significa `push bp`, salva il valore corrente nel registro Base Pointer.
- esegue in 0x0001 i byte 0xff 0x00, significa `inc word [bx+si]`, incrementa il byte 0x00 di 0x55, quindi diventa 0x56. Se andassimo a leggere ora il valore di 0x0000:0x0000, il valore è proprio 0x56.
- esegue in 0x0002 i byte 0x0F 0x53, significa `lock push bx` che in questo momento è una instruzione non valida. Quindi eleva una eccezione *Invalid opcode*, interrupt numero 6.

Quindi la CPU va a leggere nella tabella IVT l'eccezione, che si trova all'indirizzo 6 * 4 = 0x18. Dentro troviamo `53 FF 00 F0` che in Little Endian corrisponde a 0xF000:0xFF53. A questo indirizzo di memoria, l'istruzione che la CPU esegue è `CF` cioè `iret`, torna da dove sei venuto. Quindi la CPU torna a eseguire l'istruzione con IP=0x0002 e va in loop all'infinito.

Per interrompere la CPU mettendola in halt, posso aggiungere la prima istruzione all'interno del disco. Uso il comando `printf "\xF4" | dd of=disk.img bs=1 seek=0 conv=notrunc`. Con xxd:

```
00000000: f400 0000 0000 0000 0000 0000 0000 0000  ................
00000010: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000030: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000040: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000050: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000060: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000070: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000080: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000090: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000c0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000d0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000e0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000f0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000100: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000110: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000120: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000130: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000140: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000150: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000160: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000170: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000180: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000190: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001c0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001d0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001e0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001f0: 0000 0000 0000 0000 0000 0000 0000 55aa  ..............U.
```

0xF4 mette in halt la CPU, stoppandola quando legge 0xFC00. Il problema è che di base il PC ha gli interrupt hardware attivi, quindi (dopo un periodo predefinito dall'HW), viene risvegliata la CPU per aggiornare l'orario HW, la CPU continua con 0xFC01 e il ciclo si ripete.

Per impedire questa cosa e fermare veramente la CPU, basta disattivare questo flag con 0xFA. Quindi con `printf "\xFA\xF4" | dd of=disk.img bs=1 seek=0 conv=notrunc` disattivo il flag dell'interrupt hardware e poi metto in halt la cpu.

```
00000000: faf4 0000 0000 0000 0000 0000 0000 0000  ................
00000010: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000020: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000030: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000040: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000050: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000060: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000070: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000080: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000090: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000c0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000d0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000e0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000000f0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000100: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000110: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000120: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000130: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000140: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000150: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000160: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000170: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000180: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000190: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001a0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001b0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001c0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001d0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001e0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
000001f0: 0000 0000 0000 0000 0000 0000 0000 55aa  ..............U.
```

Ora, eseguendo la vm, la CPU rimane a 0 di consumo e HLT=1 quindi la CPU è ferma.

```
qemu-system-i386 -drive format=raw,file=disk.img -monitor stdio
QEMU 10.2.1 monitor - type 'help' for more information
(qemu) info registers

CPU#0
EAX=0000aa55 EBX=00000000 ECX=00000000 EDX=00000080
ESI=00000000 EDI=00000000 EBP=00000000 ESP=00006f0c
EIP=00007c02 EFL=00000002 [-------] CPL=0 II=0 A20=1 SMM=0 HLT=1
ES =0000 00000000 0000ffff 00009300
CS =0000 00000000 0000ffff 00009b00
SS =0000 00000000 0000ffff 00009300
DS =0000 00000000 0000ffff 00009300
FS =0000 00000000 0000ffff 00009300
GS =0000 00000000 0000ffff 00009300
LDT=0000 00000000 0000ffff 00008200
TR =0000 00000000 0000ffff 00008b00
GDT=     00000000 00000000
IDT=     00000000 000003ff
CR0=00000010 CR2=00000000 CR3=00000000 CR4=00000000
DR0=00000000 DR1=00000000 DR2=00000000 DR3=00000000 
DR6=ffff0ff0 DR7=00000400
EFER=0000000000000000
FCW=037f FSW=0000 [ST=0] FTW=00 MXCSR=00001f80
FPR0=0000000000000000 0000 FPR1=0000000000000000 0000
FPR2=0000000000000000 0000 FPR3=0000000000000000 0000
FPR4=0000000000000000 0000 FPR5=0000000000000000 0000
FPR6=0000000000000000 0000 FPR7=0000000000000000 0000
XMM00=0000000000000000 0000000000000000 XMM01=0000000000000000 0000000000000000
XMM02=0000000000000000 0000000000000000 XMM03=0000000000000000 0000000000000000
XMM04=0000000000000000 0000000000000000 XMM05=0000000000000000 0000000000000000
XMM06=0000000000000000 0000000000000000 XMM07=0000000000000000 0000000000000000
(qemu) quit
```



# SimoneOS

Un sistema operativo scritto da zero, un passo alla volta, per imparare a programmare e capire come funziona davvero un computer: dalla prima istruzione eseguita dopo l'accensione fino a processi, memoria virtuale e filesystem.

Il codice è scritto a mano, senza librerie e senza scorciatoie. Ogni passo è accompagnato dalla teoria e da esperimenti che la verificano sulla macchina.

## Strumenti

| Strumento | A cosa serve |
|---|---|
| `qemu-system-i386` | La macchina virtuale su cui gira il sistema |
| `nasm` / `ndisasm` | Assembler e disassembler x86 |
| `gcc`, `make` | Compilatore C e automazione della build (dalla fase 2) |
| `gdb` | Debug passo per passo |
| `xxd`, `dd`, `objdump` | Ispezionare e modificare file binari |

Su Ubuntu: `sudo apt install qemu-system-x86 nasm build-essential gdb`

## Percorso

Architettura **x86**, avvio da **BIOS**, prima in **Assembly** e poi in **C**.

| Fase | Cosa si costruisce | Cosa si impara | Stato |
|---|---|---|---|
| 0 | Ambiente di lavoro | Binario, esadecimale, CPU, registri, memoria | ✅ |
| 1 | Settore di boot da 512 byte | Reset, BIOS, real mode, Assembly | 🚧 |
| 2 | Programmi C su Linux | Il linguaggio C, puntatori, compilazione | |
| 3 | Passaggio a protected mode | Segmentazione, GDT | |
| 4 | Kernel in C (video e seriale) | Linker, collegare Assembly e C, memory-mapped I/O | |
| 5 | Interrupt, timer, tastiera | IDT, PIC, eccezioni | |
| 6 | Gestione della memoria | Paginazione, allocatore | |
| 7 | Multitasking, syscall, userspace, filesystem | Il cuore di un sistema operativo | |

## Lezioni

- [Lezione 1: dall'accensione alla prima istruzione](#lezione-1-dallaccensione-alla-prima-istruzione)
- [Lezione 2: l'assembler e il primo settore di boot](#lezione-2-lassembler-e-il-primo-settore-di-boot)

---

## Lezione 1: dall'accensione alla prima istruzione

### 1.1 Cos'è un computer

Ridotto all'essenziale, un computer è una **CPU** collegata a una **memoria**.

- La **memoria** è un enorme array di byte. Ogni byte ha un numero progressivo, il suo **indirizzo**, e contiene un valore da 0 a 255. In memoria non esistono tipi, variabili o file: solo byte numerati.
- La **CPU** ripete all'infinito lo stesso ciclo:
  1. **Fetch**: legge i byte all'indirizzo indicato dall'**Instruction Pointer** (IP) e sposta subito IP sull'istruzione successiva;
  2. **Decode**: interpreta quei byte come un'istruzione (per esempio `F4` = `hlt`, fermati);
  3. **Execute**: la esegue. Un salto non fa altro che sovrascrivere IP.

**La CPU non distingue il codice dai dati.** In memoria ci sono solo byte, e diventano "codice" nel momento in cui IP ci punta sopra. Questa idea si chiama **architettura di von Neumann**:

- è una forza: un programma si può copiare e caricare come un dato qualunque, ed è così che il BIOS carica il settore di boot;
- è un pericolo: se IP finisce nel posto sbagliato, la CPU esegue dati come istruzioni (lo si vede negli esperimenti qui sotto). Più avanti il sistema operativo potrà marcare zone di memoria come non eseguibili (bit NX), ma la CPU in sé non riconosce i dati.

### 1.2 I registri

I **registri** sono poche celle di memoria velocissime dentro la CPU. In modalità 16 bit:

| Registro | Nome | Uso tipico |
|---|---|---|
| AX, BX, CX, DX | Accumulator, Base, Counter, Data | Uso generale. Ognuno si divide in due metà da 8 bit: AH/AL, BH/BL… |
| SI, DI | Source Index, Destination Index | Copie di blocchi di memoria |
| SP, BP | Stack Pointer, Base Pointer | Lo stack |
| IP | Instruction Pointer | La prossima istruzione da leggere |
| CS, DS, ES, SS | Code, Data, Extra, Stack Segment | Scelgono la "finestra" di memoria |
| FLAGS | | Bit di stato: zero, riporto, segno, interrupt abilitati (IF)… |

### 1.3 Esadecimale

Una cifra esadecimale rappresenta esattamente 4 bit, quindi un byte si scrive sempre con 2 cifre:

```
binario   1111 0100
hex          F    4   →  0xF4  (244 decimale)
```

Per questo nella programmazione a basso livello si usa l'esadecimale: si legge direttamente come bit. Il prefisso `0x` indica un numero esadecimale.

### 1.4 Linguaggio macchina, Assembly e C

- **Linguaggio macchina**: i byte che la CPU esegue, per esempio `F4`.
- **Assembly**: lo stesso linguaggio con nomi leggibili, per esempio `hlt`. L'assembler (NASM) traduce quasi 1 a 1.
- **C**: un livello più in alto. Una riga di C diventa molte istruzioni macchina.

### 1.5 Il reset e la prima istruzione

Quando l'alimentazione è stabile, la CPU riceve il segnale di **RESET** e ogni registro parte da un valore preciso. Tra questi:

- **CS = 0xF000**, con base nascosta **0xFFFF0000**
- **IP = 0xFFF0**

La prima istruzione viene quindi letta a **0xFFFFFFF0**, 16 byte sotto i 4 GiB: è il **reset vector**. A quell'indirizzo non c'è RAM: il chipset fa rispondere il chip flash del firmware (BIOS). Un indirizzo non è sempre RAM: lo spazio degli indirizzi è una mappa, e alcune zone sono collegate a ROM o a dispositivi (*memory-mapped I/O*).

> **La base nascosta.** Ogni registro di segmento ha una parte visibile (il valore a 16 bit) e una parte nascosta con base, limite e attributi. La CPU calcola sempre `base + offset` usando la base nascosta. In real mode, quando si carica un segmento, la base diventa `segmento × 16`. Al reset fa eccezione: CS vale 0xF000 ma la base è impostata direttamente a 0xFFFF0000. Al primo salto lontano CS viene ricaricato e la base torna a seguire la regola normale. In protected mode il valore visibile diventa un indice in una tabella (la GDT) da cui la CPU copia la base nella parte nascosta.

In una VM VMware l'hypervisor emula il chip del firmware. Scegliere "BIOS" o "EFI" nelle impostazioni della VM significa scegliere quale programma risponde a quell'indirizzo. Il BIOS di QEMU si chiama **SeaBIOS**.

### 1.6 Il BIOS: POST e servizi

1. **POST** (*Power-On Self Test*): inizializza il controller della RAM, verifica la CPU, enumera il bus PCI, trova dischi e periferiche ed esegue le ROM delle schede (per esempio i controller RAID).
2. **Servizi**: lascia in memoria delle funzioni chiamabili tramite **interrupt software**:
   - `INT 0x10`: video
   - `INT 0x13`: disco
   - `INT 0x16`: tastiera
3. **Avvio**: cerca un dispositivo avviabile seguendo il *boot order*.

### 1.7 Real mode e indirizzamento segmento:offset

Per compatibilità con l'8086 del 1978, **ogni CPU x86 si accende in real mode**: registri a 16 bit (massimo 0xFFFF, 64 KiB) ma 20 linee di indirizzo (1 MiB). Gli indirizzi si scrivono come `segmento:offset`:

```
fisico = segmento × 16 + offset
```

Moltiplicare per 16 significa spostare di una cifra esadecimale a sinistra. Coppie diverse possono indicare lo stesso byte fisico:

```
0x07C0:0x0000  →  0x07C00 + 0x0000 = 0x07C00
0x0000:0x7C00  →  0x00000 + 0x7C00 = 0x07C00
0x1234:0x0010  →  0x12340 + 0x0010 = 0x12350  =  0x1230:0x0050
```

Con CS fisso, IP può raggiungere solo una **finestra di 64 KiB**, che il segmento posiziona nel MiB. Quando IP supera 0xFFFF torna a 0x0000, sempre dentro la stessa finestra.

#### La mappa del primo MiB

```
0x00000 - 0x003FF   IVT: tabella dei vettori di interrupt
0x00400 - 0x004FF   BDA: dati del BIOS
0x00500 - 0x07BFF   libera
0x07C00 - 0x07DFF   settore di boot (512 byte)
0x07E00 - 0x7FFFF   libera
0x80000 - 0x9FFFF   in parte usata dal BIOS (EBDA)
0xA0000 - 0xBFFFF   memoria video
0xC0000 - 0xFFFFF   ROM: BIOS video, BIOS di sistema
```

### 1.8 Il settore di boot

Per ogni dispositivo del boot order, il BIOS:

1. legge il **primo settore** (LBA 0, 512 byte) e lo **copia** in RAM a **0x7C00**;
2. controlla gli ultimi due byte (offset 510 e 511): devono essere **0x55** e **0xAA**, la *firma di boot*. Se mancano, passa al dispositivo successivo; se la trova, si ferma lì e non guarda gli altri dischi;
3. mette in **DL** il numero del disco di avvio (0x80 = primo disco rigido) ed esegue un **far jump** a 0x7C00 (SeaBIOS usa `0000:7C00`).

La CPU non "riparte": dal reset ha sempre eseguito il codice del BIOS, e l'ultima istruzione del BIOS è un salto che carica CS e IP. La specifica garantisce solo l'**indirizzo fisico** 0x7C00: alcuni BIOS usano `07C0:0000`, quindi un buon settore di boot imposta da sé i registri di segmento.

Questo settore è l'**MBR** (*Master Boot Record*), che nei dischi MBR contiene anche la tabella delle partizioni (dall'offset 446).

- **Perché 0x7C00?** Il primo IBM PC aveva almeno 32 KiB di RAM (0x8000). Il settore fu messo vicino alla fine, lasciando 1 KiB per sé e per lo stack: 0x8000 − 0x400 = 0x7C00.
- **Little-endian.** Le CPU x86 salvano i numeri di più byte partendo dal byte **meno significativo**. Il valore 0xAA55 in memoria diventa `55 AA`, e 0x1234 scritto a 0x500 mette `34` a 0x500 e `12` a 0x501.

### 1.9 Riepilogo

```
RESET → real mode, CS:IP → 0xFFFFFFF0
      → far jump nel BIOS
      → POST, IVT, servizi INT
      → boot order: legge LBA 0 → 0x7C00
      → firma 55 AA? no → dispositivo successivo
                     sì → DL = disco, far jump a 0000:7C00
      → la CPU esegue i nostri byte
```

### Esercizi della lezione 1

#### Esercizio 1

Scrivere questo readme

#### Esercizio 2

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

Quindi corrisponde a quello che è stato detto in precedenza, CS è impostato come 0xF000 ma la base nascosta è 0xFFFF0000 e l'offset EIP è 0xFFF0.

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

#### Esercizio 3

Far partire la vm con un disco non bootabile

Creo un disco da 512 byte con `dd if=/dev/zero of=./disk.img bs=512 count=1`, poi eseguo `qemu-system-i386 -drive format=raw,file=disk.img`. Possiamo vedere che la vm parte, passa al BIOS che non trova nessun disco con una partizione bootabile, tenta altre sorgenti e infine si ferma. Questo succede perché manca la firma di boot 0xAA55.

#### Esercizio 4

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

In questo modo il BIOS vede che è un disco di boot. Copia il contenuto all'indirizzo 0x7C00, poi fa un far jump a 0x0000:0x7C00, che carica insieme CS=0x0000 e IP=0x7C00.  
Da questo momento la CPU esegue il codice scritto dentro al disco. Dentro c'è una lista di 0x00 e la firma in fondo, ma anche gli zeri sono istruzioni: `00 00` è `add [bx+si], al`, che somma AL al byte all'indirizzo 0 (BX = SI = 0). Anche la firma viene eseguita: `55` è `push bp` e `AA` è `stosb`, che scrive AL (0x55) all'indirizzo ES:DI = 0x0000 e porta DI a 1. Poi la CPU prosegue sulla RAM dopo il settore.  
Una volta che IP arriva a 0xFFFF, ricomincia da capo e setta IP=0x0000, essendo CS=0x0000, la CPU esegue il codice dentro alla tabella dei vettori IVT all'inizio della memoria.  

Quello che succede è questo:

- esegue in 0x0000 il byte 0x55, significa `push bp`, salva il valore corrente nel registro Base Pointer.
- esegue in 0x0001 i byte 0xff 0x00, significa `inc word [bx+si]`, incrementa di 1 il byte all'indirizzo 0x0000, che vale 0x55 (scritto da `stosb`), quindi diventa 0x56. Se andassimo a leggere ora il valore di 0x0000:0x0000, il valore è proprio 0x56.
- esegue in 0x0003 i byte 0xF0 0x53, significa `lock push bx` che è una istruzione non valida: `lock` si può usare solo con istruzioni che scrivono in memoria. Questi byte non sono codice, sono pezzi degli indirizzi della IVT preparati dal BIOS. Quindi eleva una eccezione *Invalid opcode*, interrupt numero 6.

Quindi la CPU va a leggere nella tabella IVT l'eccezione, che si trova all'indirizzo 6 * 4 = 0x18. Dentro troviamo `53 FF 00 F0` che in Little Endian corrisponde a 0xF000:0xFF53. A questo indirizzo di memoria, l'istruzione che la CPU esegue è `CF` cioè `iret`, torna da dove sei venuto. Quindi la CPU torna a eseguire l'istruzione con IP=0x0003 e va in loop all'infinito.

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

0xF4 mette in halt la CPU, fermandola dopo averlo letto a 0x7C00. Il problema è che di base il PC ha gli interrupt hardware attivi, quindi (dopo un periodo predefinito dall'HW), viene risvegliata la CPU per aggiornare l'orario HW, dopo il gestore dell'interrupt la CPU continua da 0x7C01 (gli zeri) e finisce nello stesso ciclo infinito di prima.

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

Se il BIOS avesse saltato a `07C0:0000` (stesso indirizzo fisico), IP avrebbe percorso 0x07C00–0x17BFF e dopo il giro sarebbe tornato a 0x7C00, all'inizio del settore: stesso indirizzo fisico, comportamento diverso.

Nota: con `-S` la VM resta in pausa prima della prima istruzione (EIP = 0xFFF0). HLT=0 e CPU allo 0% non significano che il programma si è fermato: la VM non è mai partita. Nel monitor, `c` la fa ripartire.

Restano gli **NMI** (*Non-Maskable Interrupt*), che `cli` non blocca: il codice robusto mette `hlt` in un ciclo, così se la CPU viene svegliata torna a dormire. È il primo esercizio della lezione 2.

---

## Lezione 2: l'assembler e il primo settore di boot

### 2.1 Cosa fa un assembler

NASM è un **traduttore**: legge testo e produce byte, senza aggiungere niente.

1. **Traduce i nomi delle istruzioni in byte**: `cli` → `FA`.
2. **Calcola gli indirizzi**: tiene il conto di dove finirà ogni byte e sostituisce ogni **etichetta** con il suo indirizzo. Un'etichetta non è una variabile: è un nome per un indirizzo, e nel file finale resta solo il numero.

Il BIOS non sa leggere formati con intestazione come ELF (Linux) o PE (Windows): copia 512 byte e ci salta dentro. Serve un **binario puro**:

```
nasm -f bin boot.asm -o boot.bin -l boot.lst
```

Il **listing** (`-l`) mostra, per ogni riga del sorgente, l'indirizzo e i byte generati.

### 2.2 La sintassi di NASM

```
etichetta:   istruzione   destinazione, sorgente   ; commento
```

`mov` **copia** un valore, sempre nell'ordine destinazione ← sorgente:

```nasm
mov ax, 5          ; immediato: AX = 5
mov ax, bx         ; registro:  AX = BX
mov al, [0x500]    ; memoria:   AL = il byte CONTENUTO all'indirizzo 0x500
mov si, dato       ; SI = l'INDIRIZZO dell'etichetta dato
mov al, [si]       ; AL = il byte all'indirizzo contenuto in SI (un puntatore)
```

Le **parentesi quadre** significano "vai in memoria a quell'indirizzo", e passano per un segmento: `[si]` è in realtà `DS:SI`.

#### Direttive

Ordini per l'assembler, non istruzioni per la CPU:

| Direttiva | Significato |
|---|---|
| `bits 16` | Genera codice per la modalità 16 bit |
| `org 0x7C00` | Calcola gli indirizzi come se il codice partisse da 0x7C00 |
| `db` | Scrive byte così come sono, anche testo: `db 'ciao'` |
| `dw` | Scrive un valore a 16 bit, in little-endian |
| `times N ...` | Ripete N volte |
| `$` / `$$` | Indirizzo della riga corrente / dell'inizio; `$ - $$` = byte scritti finora |

**`org` non sposta il codice e non genera byte**: cambia solo i numeri che NASM mette al posto delle etichette. Senza `org` NASM conta da 0, e un'etichetta al byte 32 varrebbe 32, cioè un indirizzo dentro la IVT. `org 0x7C00` funziona solo se **DS = 0**, perché l'indirizzo fisico è `DS × 16 + etichetta`.

### 2.3 Salti, confronti e flag

- **`jmp` corto** (`EB xx`): i byte contengono la **distanza** dall'IP già avanzato, come numero con segno a 8 bit (−128…+127, complemento a due: `FF` = −1, `FE` = −2…). Funziona ovunque venga caricato il codice.
- **Far jump** (`jmp segmento:offset`, codice `EA`): carica insieme CS e IP. È l'unico modo per impostare CS.
- **`cmp a, b`** calcola `a − b`, scarta il risultato e aggiorna i flag. **ZF** (*Zero Flag*) = 1 se il risultato è 0.
- **`je`/`jz`** saltano se ZF = 1, **`jne`/`jnz`** se ZF = 0.

Ogni `if` e ogni `while` si costruisce così: un confronto che imposta un flag e un salto che lo legge.

### 2.4 Lo stack

Una pila gestita da **SS:SP**, che **cresce verso il basso**:

- `push ax`: SP = SP − 2, poi scrive AX a SS:SP;
- `pop ax`: legge da SS:SP, poi SP = SP + 2.

La CPU usa lo stack **da sola** a ogni interrupt, per salvare il punto di ritorno, quindi va preparato prima di tutto. Scelta classica: **SS = 0, SP = 0x7C00**, così lo stack cresce verso 0x500, allontanandosi dal codice.

- Dopo una `mov ss, ...` la CPU blocca gli interrupt fino alla fine dell'istruzione successiva: se quell'istruzione imposta SP, la coppia è al sicuro. Molti bootloader usano comunque `cli` … `sti`.
- Non esiste `mov ds, 0`: nei registri di segmento si scrive passando da un registro generale.

### 2.5 `int` e i servizi del BIOS

`int n` fa la stessa cosa di un'eccezione, ma su richiesta:

1. salva sullo stack FLAGS, CS e IP (già avanzato);
2. azzera IF;
3. legge la voce `n` della IVT a `n × 4` (offset, poi segmento, in little-endian);
4. salta lì. Il gestore termina con `iret`.

Interrupt hardware, eccezioni e chiamate software usano lo stesso meccanismo.

**Teletype del BIOS**: `INT 0x10` con **AH = 0x0E** scrive il carattere in **AL** (pagina video in **BH** = 0) e sposta il cursore. I parametri passano in registri concordati: è un'**ABI**.

Per andare a capo servono due caratteri, come sulle telescriventi: **CR** (0x0D) riporta il cursore a inizio riga, **LF** (0x0A) scende di una riga. È l'origine del `\r\n` di Windows.

### 2.6 Le stringhe

Ogni carattere è un numero (**ASCII**: `'A'` = 0x41, `'a'` = 0x61, `'0'` = 0x30, spazio = 0x20). Una stringa è una sequenza di byte terminata da **0** (*null-terminated*), come in C.

`lodsb` carica in AL il byte a DS:SI e incrementa SI, se il *Direction Flag* è 0. `cld` lo azzera: meglio non darlo per scontato.

### 2.7 La struttura di un settore di boot

```
1. bits 16, org 0x7C00
2. far jump per fissare CS
3. DS, ES, SS, SP (e cld)
4. il lavoro: stampare il messaggio
5. ciclo di arresto: hlt, e se qualcosa ci sveglia di nuovo hlt
6. i dati (dopo il ciclo, altrimenti la CPU li eseguirebbe)
7. zeri fino al byte 510
8. la firma 0xAA55
```

### Esercizi della lezione 2

- [x] **1.** Riscrivere `cli` + `hlt` in `boot.asm` con riempimento e firma; prevedere i byte e la dimensione; confrontare con `cmp` con l'immagine fatta a mano.
- [ ] **2.** Ciclo di arresto con etichetta, `hlt` e `jmp`; prevedere i byte del `jmp` e verificarli con `ndisasm -o 0x7C00 boot.bin`.
- [ ] **3.** Struttura completa (far jump, segmenti, stack) e stampa di un carattere con `INT 0x10`.
- [ ] **4.** Stampa di una stringa terminata da 0 con un ciclo, preceduta da un a capo.
- [ ] **5.** Togliere `org 0x7C00` e spiegare con il listing cosa stampa la CPU.

#### Esercizio 1: risultati

Il sorgente [`boot.asm`](boot.asm):

```nasm
bits 16
org 0x7C00
cli
hlt
times 510-($-$$) db 0x00
dw 0xAA55
```

Assemblato con:

```
nasm -f bin boot.asm -o boot.bin -l boot.lst
```

Il file `boot.bin` è di **512 byte** esatti. Con `xxd boot.bin | sed -n '1p;$p'`:

```
00000000: faf4 0000 0000 0000 0000 0000 0000 0000  ................
000001f0: 0000 0000 0000 0000 0000 0000 0000 55aa  ..............U.
```

- `FA F4` all'inizio: `cli` e `hlt`, tradotti da NASM negli stessi byte scritti a mano nella lezione 1.
- `times 510-($-$$) db 0x00`: alla riga di `times`, `$` (la riga corrente) vale 0x7C02 e `$$` (l'inizio) vale 0x7C00, quindi `$-$$` = 2 byte già scritti e servono 510 − 2 = 508 zeri. Le parentesi sono necessarie: `510-$-$$` vorrebbe dire 510 − 0x7C02 − 0x7C00.
- `dw 0xAA55` scrive `55 AA` per via del little-endian.

Ricreata l'immagine fatta a mano (512 byte di zeri, `FA F4` all'inizio e `55 AA` alla fine con `dd` e `printf`), il confronto con `cmp boot.bin disk.img` non stampa nulla: **i due file sono identici byte per byte**. L'assembler non aggiunge niente, traduce soltanto.

Avvio con `qemu-system-i386 -drive format=raw,file=boot.bin -monitor stdio` e `info registers`:

```
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
```

Funziona come previsto, con lo stesso risultato dell'esperimento della lezione 1:

- **HLT=1** e QEMU a circa lo 0% di CPU: la CPU è ferma su `hlt`;
- **EIP=0x7C02**: IP punta già all'istruzione dopo `hlt`;
- **EFL=0x00000002**: IF = 0, effetto di `cli`;
- **CS=0000** e **DL=0x80**: SeaBIOS ha saltato a `0000:7C00` dal primo disco rigido.

#### Domande di verifica

1. Che differenza c'è tra `mov si, msg` e `mov al, [msg]`?
2. Perché un'etichetta "sparisce" nel file finale, e cosa resta al suo posto?
3. Perché la stringa va dopo il ciclo di arresto?
4. Con lo stack lasciato a SS:SP = 0000:7C10, cosa rischia il codice al primo interrupt del timer?
5. Un `jmp` corto a 0x7C10 ha distanza `0x05`: dove salta la CPU?

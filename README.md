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

### Esperimenti della lezione 1

#### Esperimento 1: osservare il reset

`qemu-system-i386 -S -monitor stdio` crea la VM **in pausa prima della prima istruzione** e apre il monitor di QEMU. Con `info registers`:

```
EIP=0000fff0 EFL=00000002 [-------] CPL=0 II=0 A20=1 SMM=0 HLT=0
CS =f000 ffff0000 0000ffff 00009b00
```

CS vale `f000` ma la base (seconda colonna) è `ffff0000`: base nascosta + EIP = **0xFFFFFFF0**, come previsto.

Il contenuto del reset vector, con `xp /16xb 0xfffffff0`:

```
00000000fffffff0: 0xea 0x5b 0xe0 0x00 0xf0 0x30 0x36 0x2f
00000000fffffff8: 0x32 0x33 0x2f 0x39 0x39 0x00 0xfc 0x00
```

- `EA` è il codice del **far jump**: i 4 byte successivi sono offset e segmento, in little-endian.
- `5B E0` → offset **0xE05B**; `00 F0` → segmento **0xF000**.
- L'istruzione è `jmp 0xF000:0xE05B`. Dopo il salto la base segue la regola normale: 0xF0000 + 0xE05B = **0xFE05B**, dentro la ROM del BIOS.
- I byte seguenti non sono codice: `06/23/99` è la data del BIOS, e `FC` è il codice di modello "IBM PC/AT", conservato per compatibilità.

> Attenzione: con `-S` la VM resta in pausa. HLT=0 e CPU allo 0% non significano che il programma si è fermato: la VM non è mai partita (EIP = 0xFFF0). Nel monitor, `c` la fa ripartire.

#### Esperimento 2: un disco non avviabile

```
dd if=/dev/zero of=disk.img bs=512 count=1
qemu-system-i386 -drive format=raw,file=disk.img
```

Il BIOS non trova la firma, prova le altre sorgenti di avvio e si ferma con un messaggio di errore.

#### Esperimento 3: firmare il disco

```
printf '\x55\xAA' | dd of=disk.img bs=1 seek=510 conv=notrunc
xxd disk.img | tail -1
000001f0: 0000 0000 0000 0000 0000 0000 0000 55aa  ..............U.
```

Il BIOS accetta il disco, lo copia a 0x7C00 e ci salta. Nel monitor, `xp /2xb 0x7dfe` mostra `55 AA`: l'offset 510 (0x1FE) del disco è finito a 0x7C00 + 0x1FE = **0x7DFE**, la prova della copia.

La VM sembra bloccata, ma **la CPU lavora al 100%**. Ecco cosa esegue:

1. **Gli zeri del settore.** `00 00` non è un'istruzione vuota (quella sarebbe `nop`, 0x90): è `add [bx+si], al`. Con BX = SI = 0 somma AL al byte all'indirizzo 0. Ogni istruzione scrive in memoria.
2. **La firma.** Anche lei viene eseguita: `55` = `push bp`, `AA` = `stosb`, che scrive AL a ES:DI (cioè a 0) e incrementa DI (DI = 1 alla fine).
3. **Oltre il settore.** La CPU continua sulla RAM successiva (zeri) fino a IP = 0xFFFF.
4. **Il giro di IP.** IP è a 16 bit: torna a 0x0000 e, con CS = 0, la CPU esegue **la IVT come se fosse codice**.
5. **La trappola.** I byte all'inizio della memoria diventano:
   ```
   0x0000   55      push bp
   0x0001   FF 00   inc word [bx+si]   ← il byte a 0 passa da 0x55 a 0x56
   0x0003   F0 53   lock push bx       ← istruzione non valida
   ```
   `F0 53` non è codice scritto da qualcuno: sono pezzi di indirizzi della IVT, preparati dal BIOS. La CPU li interpreta come `lock push bx`, una combinazione non valida, e genera l'eccezione **Invalid Opcode** (interrupt 6).
6. **Il ciclo infinito.** La CPU legge il gestore nella voce 6 della IVT, a 6 × 4 = 0x18: `53 FF 00 F0` → **F000:FF53**. Lì c'è un solo byte, `CF` = `iret`, che torna all'istruzione che ha causato l'errore. Eccezione, gestore, ritorno, eccezione… per sempre. `info registers` mostra sempre **EIP=00000003**, con HLT=0.

In real mode non c'è alcuna protezione: questo "programma" di zeri ha modificato la tabella degli interrupt del BIOS senza che nessuno lo impedisse.

Se il BIOS avesse saltato a `07C0:0000` (stesso indirizzo fisico), la finestra di IP sarebbe stata 0x07C00–0x17BFF e dopo il giro la CPU sarebbe tornata a 0x7C00, all'inizio del nostro settore: stesso indirizzo, comportamento completamente diverso.

#### Esperimento 4: `hlt` e gli interrupt

Con `F4` (`hlt`) come primo byte la CPU si ferma, ma solo per pochi millisecondi. Il BIOS lascia gli **interrupt hardware attivi** (flag **IF** = bit 9 di FLAGS) e il timer di sistema (**PIT**) genera un interrupt circa **18,2 volte al secondo**. Al primo tick la CPU si risveglia, esegue il gestore del BIOS, e `iret` la riporta all'istruzione **dopo** `hlt` (0x7C01): gli zeri, e poi la stessa trappola dell'esperimento 3.

#### Esperimento 5: il primo programma

```
printf '\xFA\xF4' | dd of=disk.img bs=1 seek=0 conv=notrunc
```

```
0x7C00   FA   cli    → IF = 0, gli interrupt hardware vengono ignorati
0x7C01   F4   hlt    → la CPU si ferma e il timer non può svegliarla
```

Risultato in `info registers`:

```
EAX=0000aa55 EBX=00000000 ECX=00000000 EDX=00000080
EIP=00007c02 EFL=00000002 [-------] CPL=0 II=0 A20=1 SMM=0 HLT=1
CS =0000 00000000 0000ffff 00009b00
```

- **HLT=1** e QEMU allo **0%** di CPU: la CPU è ferma davvero.
- **EFL=0x00000002**: il bit 9 (IF) è a 0, effetto di `cli`.
- **EIP=0x7C02**, non 0x7C01: durante il fetch IP avanza **prima** dell'esecuzione, quindi mentre la CPU è ferma su `hlt` IP punta già all'istruzione successiva.
- **CS=0000**, **DL=0x80**: SeaBIOS ha saltato a `0000:7C00` dal primo disco rigido, come previsto.

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

- [ ] **1.** Riscrivere `cli` + `hlt` in `boot.asm` con riempimento e firma; prevedere i byte e la dimensione; confrontare con `cmp` con l'immagine fatta a mano.
- [ ] **2.** Ciclo di arresto con etichetta, `hlt` e `jmp`; prevedere i byte del `jmp` e verificarli con `ndisasm -o 0x7C00 boot.bin`.
- [ ] **3.** Struttura completa (far jump, segmenti, stack) e stampa di un carattere con `INT 0x10`.
- [ ] **4.** Stampa di una stringa terminata da 0 con un ciclo, preceduta da un a capo.
- [ ] **5.** Togliere `org 0x7C00` e spiegare con il listing cosa stampa la CPU.

#### Domande di verifica

1. Che differenza c'è tra `mov si, msg` e `mov al, [msg]`?
2. Perché un'etichetta "sparisce" nel file finale, e cosa resta al suo posto?
3. Perché la stringa va dopo il ciclo di arresto?
4. Con lo stack lasciato a SS:SP = 0000:7C10, cosa rischia il codice al primo interrupt del timer?
5. Un `jmp` corto a 0x7C10 ha distanza `0x05`: dove salta la CPU?

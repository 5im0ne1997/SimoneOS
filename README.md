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



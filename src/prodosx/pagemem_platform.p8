;
; pagemem for the ProDOS 128 KB build (p8vi-prodosx): the page store's pages
; are in the auxiliary 64 KB (src/prodosx/auxmem.p8), page_size bytes each,
; and are copied into one of up to SLOTS cache slots in main RAM to be
; used.  The least recently used slot is written back first if it was
; changed.  Only the last page mapped is sure to stay in its slot.  Aux
; memory starts with two header slots of HEADER_SIZE bytes (to find the
; text again after a reset: the memory keeps its contents,
; docs/XMEM-DESIGN.md); the pages come after them.
;
; Aux $0800-$bfff (what AUXMOVE reaches, less the text screen's page there,
; $0400-$07ff, which an 80-column screen would use): the headers at $0800
; and $0c00, 44 pages of 1 KB from $1000.  ProDOS's /RAM, which keeps its
; files there, is disconnected first (auxmem.disconnect_ram).
;
; A slot is in the spare memory between the variables and the program
; ($0800-$1fff, platform.sparestart) if there is room, then the scratch
; buffer there or off the top of the text memory, and the other slots at
; the start of the text memory.
;
; Without aux memory (a 64 KB machine) this build says so and ends: what
; main RAM has after it is less than a page (p8vi-prodos is the build for
; 64 KB).
;
%import auxmem

pagemem {
    const uword NO_PAGE = $ffff
    ; bytes per page
    const uword PAGE_SIZE = 1024
    ; changed pages are copies that have to be written back (the editor
    ; avoids changing pages it only reads: buffer.WRITE_BACK)
    const bool WRITE_BACK = true
    ; (a page can't fail to be written here: see src/diskpage)
    const bool CAN_FAIL = false
    const bool failed = false
    sub retry() -> bool {
        return true
    }
    ; the pages aux memory holds (the page store's tables are this size)
    const ubyte MAX_PAGES = 44
    ; SCRATCH_SIZE bytes for the page store's buffers: 2 * BOUNCE_SIZE +
    ; MAX_PAGES + H_IDS + 32 + 2 * STREAM_PAGES (pagestore.p8, as the C128's
    ; bank 1 build has it)
    const uword SCRATCH_SIZE = 2 * 128 + MAX_PAGES + 64 + 32 + 2 * 64
    uword scratch
    const ubyte SLOTS = 4
    const uword HEADER_SIZE = 1024
    ; aux memory: the headers, then the pages
    const uword AUX_HEADERS = $0800
    const uword AUX_PAGES = AUX_HEADERS + 2 * HEADER_SIZE
    const uword AUX_TOP = $c000

    uword size              ; bytes per page
    const bool persistent = true    ; the pages survive a reset: there are headers
    uword last_id = NO_PAGE ; the page mapped last
    uword last_addr         ; its address
    ubyte last_slot         ; its slot
    ubyte nslots            ; slots in use

    ; the page in each slot, NO_SLOT_PAGE for none.  (ubyte, like page ids:
    ; comparing a uword array element with a ubyte goes wrong, see
    ; bugs/uword_array_eq_ubyte.p8)
    const ubyte NO_SLOT_PAGE = 255
    ubyte[SLOTS] slot_page
    bool[SLOTS] slot_dirty  ; changed since it was copied in
    ubyte[SLOTS] slot_used  ; when it was mapped last (clock)
    uword[SLOTS] slot_addr  ; where it is in main RAM
    ubyte clock

    ; the slots and the scratch buffer: the spare memory first, then main
    ; RAM from start to top.  returns how many pages there are (at most
    ; max_pages).
    sub init(uword start, uword top, uword page_size, ubyte max_pages) -> uword {
        uword n
        ubyte i
        size = page_size
        nslots = 0
        if not auxmem.present() {
            platform.stop()
            txt.print("p8vi-prodosx needs 128 KB: p8vi-prodos is for 64 KB\n")
            sys.exit(1)
        }
        ; (a slot in the spare memory first: the scratch buffer fits in
        ; less room, which is all the text memory may have)
        if platform.sparetop - platform.sparestart >= size {
            slot_addr[0] = platform.sparestart
            platform.sparestart += size
            nslots = 1
        }
        if platform.sparetop - platform.sparestart >= SCRATCH_SIZE {
            scratch = platform.sparestart
            platform.sparestart += SCRATCH_SIZE
        } else {
            scratch = top - SCRATCH_SIZE
            top -= SCRATCH_SIZE
        }
        auxmem.disconnect_ram()
        while nslots < SLOTS and top - start >= size {
            slot_addr[nslots] = start
            start += size
            nslots++
        }
        ; with no slot the store hangs: say so when code growth has taken
        ; the room (one slot is enough)
        if nslots == 0 {
            platform.stop()
            txt.print("no room for the page slots\n")
            sys.exit(1)
        }
        for i in 0 to SLOTS - 1 {
            slot_page[i] = NO_SLOT_PAGE
            slot_dirty[i] = false
            slot_used[i] = 0
        }
        n = (AUX_TOP - AUX_PAGES) / size
        if n > max_pages
            n = max_pages
        last_id = NO_PAGE
        return n
    }

    ; the address of page id until the next map()
    sub map(ubyte id) -> uword {
        ubyte s
        ubyte oldest = 0
        if id == last_id
            return last_addr
        last_id = id
        clock++
        ; in a slot already?
        for s in 0 to nslots - 1 {
            if slot_page[s] == id
                goto found
            ; (the oldest is the one used the longest clock ticks ago)
            if clock - slot_used[s] > clock - slot_used[oldest]
                oldest = s
        }
        ; no: into the least recently used slot
        s = oldest
        if slot_dirty[s]
            auxmem.stash(slot_addr[s], page_address(slot_page[s]), size)
        slot_page[s] = id
        slot_dirty[s] = false
        auxmem.fetch(page_address(id), slot_addr[s], size)
found:
        slot_used[s] = clock
        last_slot = s
        last_addr = slot_addr[s]
        return last_addr
    }

    ; where page id is in aux memory
    sub page_address(ubyte id) -> uword {
        return AUX_PAGES + id * size
    }

    ; copy count bytes from src to header slot h at offset, or (get) from
    ; there to dest
    sub header_put(ubyte h, uword offset, uword src, uword count) {
        auxmem.stash(src, AUX_HEADERS + h * HEADER_SIZE + offset, count)
    }

    sub header_get(ubyte h, uword offset, uword dest, uword count) {
        auxmem.fetch(AUX_HEADERS + h * HEADER_SIZE + offset, dest, count)
    }

    ; the page mapped last was written to
    sub changed() {
        slot_dirty[last_slot] = true
    }

    ; write changed pages back to aux memory
    sub sync() {
        ubyte s
        for s in 0 to nslots - 1 {
            if slot_dirty[s] {
                auxmem.stash(slot_addr[s], page_address(slot_page[s]), size)
                slot_dirty[s] = false
            }
        }
    }
}

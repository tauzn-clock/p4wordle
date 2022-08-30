/* -*- P4_16 -*- */

/*
 * P4 Wordle
 *
 * This program implements a simple protocol. It can be carried over Ethernet
 * (Ethertype 0x1234).
 *
 * The Protocol header looks like this:
 *
 * States: 
 * - 0 -> Unchecked
 * - 1 -> No Used
 * - 2 -> Wrong Place
 * - 3 -> Right Place
 *
 * Packet Format:
 * 
 * WORDLE (6*8 = 48 bits)
 * Current_Guess (5*8 = 40 bits)
 * 1st Word (5*8 = 40 bits)
 * 1st Word State (5*2 = 10 bits) (Use 12 bits because it is difficult to define 10bits in hex)
 * 2nd Word (5*8 = 40 bits)
 * 2nd Word State (5*2 = 10 bits)
 * 3rd Word (5*8 = 40 bits)
 * 3rd Word State (5*2 = 10 bits)
 * 4th Word (5*8 = 40 bits)
 * 4th Word State (5*2 = 10 bits)
 * 5th Word (5*8 = 40 bits)
 * 5th Word State (5*2 = 10 bits)
 * 6th Word (5*8 = 40 bits)
 * 6th Word State (5*2 = 10 bits)
 * 
 * The device receives a packet, performs the check on the current word, returns outcome
 *
 * If an unknown operation is specified or the header is not valid, the packet
 * is dropped
 */


/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*
 * Define the headers the program will recognize
 */

/*
 * Standard Ethernet header
 */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

/*
 * This is a custom protocol header for the calculator. We'll use
 * etherType 0x1234 for it (see parser)
 */
const bit<16> P4WORDLE_ETYPE = 0x1234;
const bit<48> P4WORDLE_HEADER = 0x574f52444c45;
const bit<40> P4WORDLE_TEST_WORD = 0x524f555445; /*The secret word is ROUTE*/

header p4wordle_t {
   bit<48> wordle;
   bit<40> guess;
   bit<16> outcome;
}

/*
 * All headers, used in the program needs to be assembled into a single struct.
 * We only need to declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */
struct headers {
    ethernet_t   ethernet;
    p4wordle_t   p4wordle;
}

/*
 * All metadata, globally used in the program, also  needs to be assembled
 * into a single struct. As in the case of the headers, we only need to
 * declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */

struct metadata {
    bit<32> guess_counter;
    bit<32> word_list_pointer;
    bit<40> secret_word;
    
    bit<8> cur_char;
}
/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            P4WORDLE_ETYPE : check_p4wordle;
            default      : accept;
        }
    }

    state check_p4wordle {
        
        transition select(packet.lookahead<p4wordle_t>().wordle) {
            (P4WORDLE_HEADER) : parse_p4wordle;
            default           : accept;
        }
        
    }

    state parse_p4wordle {
        packet.extract(hdr.p4wordle);
        transition accept;
    }
}

/*************************************************************************
 ************   C H E C K S U M    V E R I F I C A T I O N   *************
 *************************************************************************/
control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}






/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    
    /*Here are the registers*/
    register <bit<40>>(8) word_list;
    register <bit<32>>(1) guess_counter_state;
    register <bit<32>>(1) word_list_pointer_state;

    action state_machine(bit<16> input){
        hdr.p4wordle.outcome = hdr.p4wordle.outcome | input;
    }

    action send_forward(){
         bit<48> tmp;
         tmp = hdr.ethernet.dstAddr;
         hdr.ethernet.dstAddr = hdr.ethernet.srcAddr;
         hdr.ethernet.srcAddr = tmp;
         standard_metadata.egress_spec = standard_metadata.ingress_port;
    }


    action operation_drop() {
        mark_to_drop(standard_metadata);
    }
    
    action compare_char(bit<8> cur_char, bit<3> i, bit<16> exist, bit<16> right_place){
        if (cur_char == meta.secret_word[7:0]){
            if (i==1){
                state_machine(right_place);
            }
            else{
                state_machine(exist);
            }
        }
        if (cur_char == meta.secret_word[15:8]){
            if (i==2){
                state_machine(right_place);
            }
            else{
                state_machine(exist);
            }
        }
        if (cur_char == meta.secret_word[23:16]){
            if (i==3){
                state_machine(right_place);
            }
            else{
                state_machine(exist);
            }
        }
        if (cur_char == meta.secret_word[31:24]){
            if (i==4){
                state_machine(right_place);
            }
            else{
                state_machine(exist);
            }
        }
        if (cur_char == meta.secret_word[39:32]){
            if (i==5){
                state_machine(right_place);
            }
            else{
                state_machine(exist);
            }
        }
    }

    action operation_check_char(bit<3> i){
        if (i==1){
            meta.cur_char = hdr.p4wordle.guess[7:0];
            compare_char(meta.cur_char,1,0x4000,0xc000);
            
        }
        
        if (i==2){
            meta.cur_char = hdr.p4wordle.guess[15:8];
            compare_char(meta.cur_char,2,0x1000,0x3000);
        }

        if (i==3){
            meta.cur_char = hdr.p4wordle.guess[23:16];
            compare_char(meta.cur_char,3,0x0400,0x0c00);

        }

        if (i==4){
            meta.cur_char = hdr.p4wordle.guess[31:24];
            compare_char(meta.cur_char,4,0x0100,0x0300);

        }
        
        if (i==5){
            meta.cur_char = hdr.p4wordle.guess[39:32];
            compare_char(meta.cur_char,5,0x0040,0x00c0);
        }
    }

    apply {
        word_list.write(0,0x524f555445);/*ROUTE*/
        word_list.write(1,0x5441424c45);/*TABLE*/
        word_list.write(2,0x4D41474943);/*MAGIC*/
        word_list.write(3,0x47414D4553);/*GAMES*/
        word_list.write(4,0x4D4F555345); /*MOUSE*/
        word_list.write(5,0x4241434F4E); /*BACON*/
        word_list.write(6,0x43554C5453); /*CULTS*/
        word_list.write(7,0x535441494E); /*STAIN*/


        if (hdr.p4wordle.isValid()) {

            /* State operations */
            guess_counter_state.read(meta.guess_counter, 0);
            word_list_pointer_state.read(meta.word_list_pointer, 0);
            word_list.read(meta.secret_word, meta.word_list_pointer); 

            operation_check_char(1);
            operation_check_char(2);
            operation_check_char(3);
            operation_check_char(4);
            operation_check_char(5);


            if (hdr.p4wordle.outcome == 0xffc0){
                meta.guess_counter = 0;
                meta.word_list_pointer = meta.word_list_pointer+1; 
                if (meta.word_list_pointer == 8){
                    meta.word_list_pointer = 0;
                }
            }
            else{
                meta.guess_counter = meta.guess_counter + 1;
                if (meta.guess_counter == 6){
                    meta.guess_counter = 0;
                    meta.word_list_pointer = meta.word_list_pointer + 1;
                    if (meta.word_list_pointer == 8){
                        meta.word_list_pointer = 0;
                    }
                }
            }

            guess_counter_state.write(0,meta.guess_counter);
            word_list_pointer_state.write(0, meta.word_list_pointer);



            send_forward();
        } 
        else {
            operation_drop();
        }
    }
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
 *************   C H E C K S U M    C O M P U T A T I O N   **************
 *************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
 ***********************  D E P A R S E R  *******************************
 *************************************************************************/
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.p4wordle);
    }
}

/*************************************************************************
 ***********************  S W I T T C H **********************************
 *************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;

let () = Printexc.record_backtrace true

let pp_list pp_data ?(sep = fun fmt () -> ()) fmt lst =
  let rec aux = function
    | [] -> ()
    | [ x ] -> pp_data fmt x
    | x :: r -> pp_data fmt x; sep fmt (); aux r
  in

  aux lst

type capability =
  [ `Multi_ack
  | `Multi_ack_detailed
  | `No_done
  | `Thin_pack
  | `Side_band
  | `Side_band_64k
  | `Ofs_delta
  | `Agent of string
  | `Shallow
  | `Deepen_since
  | `Deepen_not
  | `No_progress
  | `Include_tag
  | `Report_status
  | `Delete_refs
  | `Quiet
  | `Atomic
  | `Push_options
  | `Allow_tip_sha1_in_want
  | `Allow_reachable_sha1_in_want
  | `Push_cert of string
  | `Other of string
  | `Parameter of string * string ]

let string_of_capability = function
  | `Multi_ack                    -> "multi_ack"
  | `Multi_ack_detailed           -> "multi_ack_detailed"
  | `No_done                      -> "no-done"
  | `Thin_pack                    -> "thin-pack"
  | `Side_band                    -> "side-band"
  | `Side_band_64k                -> "side-band-64k"
  | `Ofs_delta                    -> "ofs-delta"
  | `Agent agent                  -> Format.sprintf "agent=%s" agent
  | `Shallow                      -> "shallow"
  | `Deepen_since                 -> "deepen-since"
  | `Deepen_not                   -> "deepen-not"
  | `No_progress                  -> "no-progress"
  | `Include_tag                  -> "include-tag"
  | `Report_status                -> "report-status"
  | `Delete_refs                  -> "delete-refs"
  | `Quiet                        -> "quiet"
  | `Atomic                       -> "atomic"
  | `Push_options                 -> "push-options"
  | `Allow_tip_sha1_in_want       -> "allow-tip-sha1-in-want"
  | `Allow_reachable_sha1_in_want -> "allow-reachable-sha1-in-want"
  | `Push_cert cert               -> Format.sprintf "push-cert=%s" cert
  | `Other capability             -> capability
  | `Parameter (key, value)       -> Format.sprintf "%s=%s" key value

exception Capability_expect_value of string

let capability_of_string ?value = function
  | "multi_ack"                    -> `Multi_ack
  | "multi_ack_detailed"           -> `Multi_ack_detailed
  | "no-done"                      -> `No_done
  | "thin-pack"                    -> `Thin_pack
  | "side-band"                    -> `Side_band
  | "side-band-64k"                -> `Side_band_64k
  | "ofs-delta"                    -> `Ofs_delta
  | "shallow"                      -> `Shallow
  | "deepen-since"                 -> `Deepen_since
  | "deepen-not"                   -> `Deepen_not
  | "no-progress"                  -> `No_progress
  | "include-tag"                  -> `Include_tag
  | "report-status"                -> `Report_status
  | "delete-refs"                  -> `Delete_refs
  | "quiet"                        -> `Quiet
  | "atomic"                       -> `Atomic
  | "push-options"                 -> `Push_options
  | "allow-tip-sha1-in-want"       -> `Allow_tip_sha1_in_want
  | "allow-reachable-sha1-in-want" -> `Allow_reachable_sha1_in_want
  | "agent"                        ->
    (match value with
     | Some value -> `Agent value
     | None -> raise (Capability_expect_value "agent"))
  | capability -> match value with
    | Some value -> `Parameter (capability, value)
    | None -> `Other capability

let pp_capability ppf = function
  | `Multi_ack                    -> Format.fprintf ppf "Multi-ACK"
  | `Multi_ack_detailed           -> Format.fprintf ppf "Multi-ACK-detailed"
  | `No_done                      -> Format.fprintf ppf "No-done"
  | `Thin_pack                    -> Format.fprintf ppf "Thin-PACK"
  | `Side_band                    -> Format.fprintf ppf "Side-Band"
  | `Side_band_64k                -> Format.fprintf ppf "Side-Band-64K"
  | `Ofs_delta                    -> Format.fprintf ppf "Offset-delta"
  | `Agent agent                  -> Format.fprintf ppf "(Agent %s)" agent
  | `Shallow                      -> Format.fprintf ppf "Shallow"
  | `Deepen_since                 -> Format.fprintf ppf "Deepen-Since"
  | `Deepen_not                   -> Format.fprintf ppf "Deepen-Not"
  | `No_progress                  -> Format.fprintf ppf "No-Progress"
  | `Include_tag                  -> Format.fprintf ppf "Include-Tag"
  | `Report_status                -> Format.fprintf ppf "Report-Status"
  | `Delete_refs                  -> Format.fprintf ppf "Delete-Refs"
  | `Quiet                        -> Format.fprintf ppf "Quiet"
  | `Atomic                       -> Format.fprintf ppf "Atomic"
  | `Push_options                 -> Format.fprintf ppf "Push-Options"
  | `Allow_tip_sha1_in_want       -> Format.fprintf ppf "Allow-Tip-SHA1-in-Want"
  | `Allow_reachable_sha1_in_want -> Format.fprintf ppf "Allow-Reachable-SHA1-in-Want"
  | `Push_cert cert               -> Format.fprintf ppf "(Push Cert %s)" cert
  | `Other capability             -> Format.fprintf ppf "(other %s)" capability
  | `Parameter (key, value)       -> Format.fprintf ppf "(%s %s)" key value

module type DECODER =
sig
  module Digest : Ihash.IDIGEST
  module Hash : Common.BASE

  type decoder

  type error =
    [ `Expected_char of char
    | `Unexpected_char of char
    | `Unexpected_flush_pkt_line
    | `No_assert_predicate of (char -> bool)
    | `Expected_string of string
    | `Unexpected_empty_pkt_line
    | `Malformed_pkt_line
    | `Unexpected_end_of_input ]

  val pp_error : Format.formatter -> error -> unit

  type 'a state =
    | Ok of 'a
    | Read of { buffer   : Cstruct.t
              ; off      : int
              ; len      : int
              ; continue : int -> 'a state }
    | Error of { err       : error
               ; buf       : Cstruct.t
               ; committed : int }

  type advertised_refs =
    { shallow      : Hash.t list
    ; refs         : (Hash.t * string * bool) list
    ; capabilities : capability list }

  val pp_advertised_refs : Format.formatter -> advertised_refs -> unit

  type shallow_update =
    { shallow   : Hash.t list
    ; unshallow : Hash.t list }

  val pp_shallow_update : Format.formatter -> shallow_update -> unit

  type acks =
    { shallow   : Hash.t list
    ; unshallow : Hash.t list
    ; acks      : (Hash.t * [ `Common | `Ready | `Continue | `ACK ]) list }

  val pp_acks : Format.formatter -> acks -> unit

  type negociation_result =
    | NAK
    | ACK of Hash.t
    | ERR of string

  val pp_negociation_result : Format.formatter -> negociation_result -> unit

  type pack =
    [ `Raw of Cstruct.t
    | `Out of Cstruct.t
    | `Err of Cstruct.t ]

  type report_status =
    { unpack   : (unit, string) result
    ; commands : (string, string * string) result list }

  val pp_report_status : Format.formatter -> report_status -> unit

  type _ transaction =
    | ReferenceDiscovery : advertised_refs transaction
    | ShallowUpdate      : shallow_update transaction
    | Negociation        : ack_mode -> acks transaction
    | NegociationResult  : negociation_result transaction
    | PACK               : side_band -> flow transaction
    | ReportStatus       : side_band -> report_status transaction
  and ack_mode =
    [ `Ack
    | `Multi_ack
    | `Multi_ack_detailed ]
  and flow =
    [ `Raw of Cstruct.t
    | `End
    | `Err of Cstruct.t
    | `Out of Cstruct.t ]
  and side_band =
    [ `Side_band
    | `Side_band_64k
    | `No_multiplexe ]

  val decode : decoder -> 'result transaction -> 'result state
  val decoder : unit -> decoder
end

module type ENCODER =
sig
  module Digest : Ihash.IDIGEST
  module Hash : Common.BASE

  type encoder

  val set_pos : encoder -> int -> unit
  val free : encoder -> Cstruct.t

  type 'a state =
    | Write of { buffer    : Cstruct.t
               ; off       : int
               ; len       : int
               ; continue  : int -> 'a state }
    | Ok of 'a

  type upload_request =
    { want         : Hash.t * Hash.t list
    ; capabilities : capability list
    ; shallow      : Hash.t list
    ; deep         : [ `Depth of int | `Timestamp of int64 | `Ref of string ] option }
  type request_command =
    [ `UploadPack
    | `ReceivePack
    | `UploadArchive ]
  type git_proto_request =
    { pathname        : string
    ; host            : (string * int option) option
    ; request_command : request_command }
  type ('a, 'b) either =
    | L of 'a
    | R of 'b
  and update_request =
    { shallow      : Hash.t list
    ; requests     : (command * command list, push_certificate) either
    ; capabilities : capability list }
  and command =
    | Create of Hash.t * string
    | Delete of Hash.t * string
    | Update of Hash.t * Hash.t * string
  and push_certificate =
    { pusher   : string
    ; pushee   : string
    ; nonce    : string
    ; options  : string list
    ; commands : command list
    ; gpg      : string list }
  type action =
    [ `GitProtoRequest of git_proto_request
    | `UploadRequest of upload_request
    | `UpdateRequest of update_request
    | `Has of Hash.t list
    | `Done
    | `Flush
    | `Shallow of Hash.t list
    | `PACK of int ]

  val encode : encoder -> action -> unit state
  val encoder : unit -> encoder
end

module type CLIENT =
sig
  module Digest : Ihash.IDIGEST with type t = Bytes.t
  module Decoder : DECODER with type Hash.t = Digest.t and module Digest = Digest
  module Encoder : ENCODER with type Hash.t = Digest.t and module Digest = Digest
  module Hash : Common.BASE

  type context

  type result =
    [ `Refs of Decoder.advertised_refs
    | `ShallowUpdate of Decoder.shallow_update
    | `Negociation of Decoder.acks
    | `NegociationResult of Decoder.negociation_result
    | `PACK of Decoder.flow
    | `Flush
    | `Nothing
    | `ReadyPACK of Cstruct.t
    | `ReportStatus of Decoder.report_status ]
  type process =
    [ `Read of (Cstruct.t * int * int * (int -> process))
    | `Write of (Cstruct.t * int * int * (int -> process))
    | `Error of (Decoder.error * Cstruct.t * int)
    | result ]
  type action =
    [ `GitProtoRequest of Encoder.git_proto_request
    | `Shallow of Hash.t list
    | `UploadRequest of Encoder.upload_request
    | `UpdateRequest of Encoder.update_request
    | `Has of Hash.t list
    | `Done
    | `Flush
    | `ReceivePACK
    | `SendPACK of int
    | `FinishPACK ]

  val capabilities : context -> capability list
  val set_capabilities : context -> capability list -> unit
  val encode : Encoder.action -> (context -> process) -> context -> process
  val decode : 'a Decoder.transaction -> ('a -> context -> process) -> context -> process
  val pp_result : Format.formatter -> result -> unit
  val run : context -> action -> process
  val context : Encoder.git_proto_request -> context * process
end

module Decoder (Digest : Ihash.IDIGEST with type t = Bytes.t)
  : DECODER with type Hash.t = Digest.t
             and module Digest = Digest =
struct
  module Digest = Digest
  module Hash   = Helper.BaseBytes

  (* XXX(dinosaure): Why this decoder? We can use Angstrom instead or another
     library. It's not my first library about the parsing (see Mr. MIME) and I
     like a lot Angstrom. But I know the limitation about Angstrom and the best
     case to use it. I already saw other libraries like ocaml-imap specifically
     to find the best way to parse an email.

     You need all the time to handle the performance, the re-usability, the
     scalability and others constraints like the memory.

     So, about the smart Git protocol, I have the choice between Angstrom,
     something similar than the PACK decoder or this decoder.

     - Angstrom is good to describe the smart Git protocol. The expressivitu is
       good and the performance is another good point. A part of Angstrom is
       about the alteration when you have some possibilities about the input. We
       have some examples when we compute the format of the Git object.

       And the best point is to avoid any headache to handle the input buffer
       about any alteration. I explained this specific point in the [Helper]
       module (which one provide a common non-blocking interface to decode
       something described by Angstrom).

       For all of this, it's a good way to use Angstrom in this case. But it's
       not the best. Indeed, the smart Git protocol is thinked in all state
       about the length of the input by the /pkt-line/ format. Which one
       describes all the time the length of the payload and limit this payload
       to 65520 bytes.

       So the big constraint about the alteration and when we need to keep some
       bytes in the current input buffer to retry the next alteration if the
       first one fails (and have a headache to handle the input) never happens.
       And if it's happen, the input is wrong.

     - like the PACK Decoder. If you look the PACK Decoder, it's another way to
       decode something in the non-blocking world. The good point is to handle
       all aspect of your decoder and, sometimes, describe a weird semantic
       about your decoder which is not available in Angstrom. You can do
       something hacky and wrap all in a good interface « à la Daniel Bünzli ».

       So if you want to do something fast and hacky in some contexts (like
       switch between a common functional way and a imperative way easily)
       because you know the constraint about your protocol/format, it's a good
       way. But you need a long time to do this is not composable so much
       because closely specific to your protocol/format.

     - like ocaml-imap. The IMAP protocol is very close the smart Git protocol
       in some way and the interface seems to be good to have an user-friendly
       interface to communicate with a Git server without a big overhead because
       the decoder is funded on some assertions about the protocol (like the PKT
       line for the smart Git protocol or the end of line for the IMAP
       protocol).

       Then, the decoder is very hacky because we don't use the continuation all
       the time (like Angstrom) to keep a complex state but just fuck all up by
       an exception.

       And the composition between some conveniences primitives is easy (more
       easy than the second way).

     So for all of this, I decide to use this way to decode the smart Git
     protocol and provide a clear interface to the user (and keep a non-blocking
     land about all). So enjoy it!
  *)

  type decoder =
    { mutable buffer : Cstruct.t
    ; mutable pos    : int
    ; mutable eop    : int option (* end of packet *)
    ; mutable max    : int }

  type error =
    [ `Expected_char of char
    | `Unexpected_char of char
    | `Unexpected_flush_pkt_line
    | `No_assert_predicate of (char -> bool)
    | `Expected_string of string
    | `Unexpected_empty_pkt_line
    | `Malformed_pkt_line
    | `Unexpected_end_of_input ]

  let err_unexpected_end_of_input    decoder = (`Unexpected_end_of_input, decoder.buffer, decoder.pos)
  let err_expected               chr decoder = (`Expected_char chr, decoder.buffer, decoder.pos)
  let err_unexpected_char        chr decoder = (`Unexpected_char chr, decoder.buffer, decoder.pos)
  let err_assert_predicate predicate decoder = (`No_assert_predicate predicate, decoder.buffer, decoder.pos)
  let err_expected_string          s decoder = (`Expected_string s, decoder.buffer, decoder.pos)
  let err_unexpected_empty_pkt_line  decoder = (`Unexpected_empty_pkt_line, decoder.buffer, decoder.pos)
  let err_malformed_pkt_line         decoder = (`Malformed_pkt_line, decoder.buffer, decoder.pos)
  let err_unexpected_flush_pkt_line  decoder = (`Unexpected_flush_pkt_line, decoder.buffer, decoder.pos)

  let pp_error fmt = function
    | `Expected_char chr -> Format.fprintf fmt "(`Expected_char %c)" chr
    | `Unexpected_char chr -> Format.fprintf fmt "(`Unexpected_char %c)" chr
    | `No_assert_predicate predicate -> Format.fprintf fmt "(`No_assert_predicate #predicate)"
    | `Expected_string s -> Format.fprintf fmt "(`Expected_string %s)" s
    | `Unexpected_empty_pkt_line -> Format.fprintf fmt "`Unexpected_empty_pkt_line"
    | `Malformed_pkt_line -> Format.fprintf fmt "`Malformed_pkt_line"
    | `Unexpected_end_of_input -> Format.fprintf fmt "`Unexpected_end_of_input"
    | `Unexpected_flush_pkt_line -> Format.fprintf fmt "`Unexpected_flush_pkt_line"

  type 'a state =
    | Ok of 'a
    | Read of { buffer     : Cstruct.t
              ; off        : int
              ; len        : int
              ; continue   : int -> 'a state }
    | Error of { err       : error
               ; buf       : Cstruct.t
               ; committed : int }

  exception Leave of (error * Cstruct.t * int)

  let p_return x decoder = Ok x

  let p_safe k decoder =
    try k decoder
    with Leave (err, buf, pos) ->
      Error { err
            ; buf
            ; committed = pos }

  let p_end_of_input decoder = match decoder.eop with
    | Some eop -> eop
    | None -> decoder.max

  let p_peek_char decoder =
    if decoder.pos < (p_end_of_input decoder)
    then Some (Cstruct.get_char decoder.buffer decoder.pos)
    else None

  let p_current decoder =
    if decoder.pos < (p_end_of_input decoder)
    then Cstruct.get_char decoder.buffer decoder.pos
    else raise (Leave (err_unexpected_end_of_input decoder))

  let p_junk_char decoder =
    if decoder.pos < (p_end_of_input decoder)
    then decoder.pos <- decoder.pos + 1
    else raise (Leave (err_unexpected_end_of_input decoder))

  let p_char chr decoder =
    match p_peek_char decoder with
    | Some chr' when chr' = chr ->
      p_junk_char decoder
    | Some _ ->
      raise (Leave (err_expected chr decoder))
    | None ->
      raise (Leave (err_unexpected_end_of_input decoder))

  let p_satisfy predicate decoder =
    match p_peek_char decoder with
    | Some chr when predicate chr ->
      p_junk_char decoder; chr
    | Some _ ->
      raise (Leave (err_assert_predicate predicate decoder))
    | None ->
      raise (Leave (err_unexpected_end_of_input decoder))

  let p_space decoder = p_char ' ' decoder
  let p_null  decoder = p_char '\000' decoder

  let p_while1 predicate decoder =
    let i0 = decoder.pos in

    while decoder.pos < (p_end_of_input decoder)
          && predicate (Cstruct.get_char decoder.buffer decoder.pos)
    do decoder.pos <- decoder.pos + 1 done;

    if i0 < decoder.pos
    then Cstruct.sub decoder.buffer i0 (decoder.pos - i0)
    else raise (Leave (err_unexpected_char (p_current decoder) decoder))

  let p_while0 predicate decoder =
    let i0 = decoder.pos in

    while decoder.pos < (p_end_of_input decoder)
          && predicate (Cstruct.get_char decoder.buffer decoder.pos)
    do decoder.pos <- decoder.pos + 1 done;

    Cstruct.sub decoder.buffer i0 (decoder.pos - i0)

  let p_string s decoder =
    let i0 = decoder.pos in
    let ln = String.length s in

    while decoder.pos < (p_end_of_input decoder)
          && (decoder.pos - i0) < ln
          && String.get s (decoder.pos - i0) = Cstruct.get_char decoder.buffer decoder.pos
    do decoder.pos <- decoder.pos + 1 done;

    if decoder.pos - i0 = ln
    then Cstruct.sub decoder.buffer i0 ln
    else raise (Leave (err_expected_string s decoder))

  let p_hexdigit decoder =
    match p_satisfy (function '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' -> true | _ -> false) decoder with
    | '0' .. '9' as chr -> Char.code chr - 48
    | 'a' .. 'f' as chr -> Char.code chr - 87
    | 'A' .. 'F' as chr -> Char.code chr - 55
    | _ -> assert false

  let p_pkt_payload ?(strict = false) k decoder expect =
    let pkt = if expect < 0 then `Malformed else if expect = 0 then `Empty else `Line expect in

    if expect <= 0
    then begin
      decoder.eop <- Some decoder.pos;
      k ~pkt decoder
    end else begin
      (* compress *)
      if decoder.pos > 0
      then begin
        Cstruct.blit decoder.buffer decoder.pos decoder.buffer 0 (decoder.max - decoder.pos);
        decoder.max <- decoder.max - decoder.pos;
        decoder.pos <- 0;
      end;

      let rec loop rest off =
        if rest <= 0
        then begin
          let off, pkt =
            if Cstruct.get_char decoder.buffer (off + rest - 1) = '\n' && not strict
            then begin
              if rest < 0
              then Cstruct.blit decoder.buffer (off + rest) decoder.buffer (off + rest - 1) (off - (off + rest));

              off - 1, `Line (expect - 1)
            end else off, `Line expect
          in

          decoder.max <- off;
          decoder.eop <- Some (off + rest);
          p_safe (k ~pkt) decoder
        end else begin
          if off >= Cstruct.len decoder.buffer
          then raise (Invalid_argument "PKT Format: payload upper than 65520 bytes")
          else Read { buffer = decoder.buffer
                    ; off = off
                    ; len = Cstruct.len decoder.buffer - off
                    ; continue = fun n -> loop (rest - n) (off + n) }
        end
      in

      loop (expect - (decoder.max - decoder.pos)) decoder.max
    end

  let p_pkt_len_safe ?(strict = false) k decoder =
    let a = p_hexdigit decoder in
    let b = p_hexdigit decoder in
    let c = p_hexdigit decoder in
    let d = p_hexdigit decoder in

    let expect = (a * (16 * 16 * 16)) + (b * (16 * 16)) + (c * 16) + d in

    if expect = 0
    then begin
      decoder.eop <- Some decoder.pos;
      k ~pkt:`Flush decoder
    end else
      p_pkt_payload ~strict k decoder (expect - 4)

  let p_pkt_line ?(strict = false) k decoder =
    decoder.eop <- None;

    if decoder.max - decoder.pos >= 4
    then p_pkt_len_safe ~strict k decoder
    else begin
      (* compress *)
      if decoder.pos > 0
      then begin
        Cstruct.blit decoder.buffer decoder.pos decoder.buffer 0 (decoder.max - decoder.pos);
        decoder.max <- decoder.max - decoder.pos;
        decoder.pos <- 0;
      end;

      let rec loop off =
        if off - decoder.pos >= 4
        then begin
          decoder.max <- off;
          p_safe (p_pkt_len_safe ~strict k) decoder
        end else begin
          if off >= Cstruct.len decoder.buffer
          then raise (Invalid_argument "PKT Format: payload upper than 65520 bytes")
          else Read { buffer = decoder.buffer
                    ; off = off
                    ; len = Cstruct.len decoder.buffer - off
                    ; continue = fun n -> loop (off + n) }
        end
      in

      loop decoder.max
    end

  let hash_of_hex_string x =
    Helper.BaseBytes.of_hex (Bytes.unsafe_of_string x)

  let zero_id = String.make (Digest.length * 2) '0' |> hash_of_hex_string

  let p_hash decoder =
    p_while1 (function '0' .. '9' | 'a' .. 'f' -> true | _ -> false) decoder
    |> Cstruct.to_string
    |> hash_of_hex_string

  let not_null = (<>) '\000'

  let p_capability decoder =
    let capability =
      p_while1
        (function '\x61' .. '\x7a' | '0' .. '9' | '-' | '_' -> true | _ -> false)
        decoder
      |> Cstruct.to_string
    in match p_peek_char decoder with
    | Some '=' ->
      p_junk_char decoder;
      let value =
        p_while1 (function '\033' .. '\126' -> true | _ -> false) decoder
        |> Cstruct.to_string in
      capability_of_string ~value capability
    | _ ->
      capability_of_string capability

  let p_capabilities1 decoder =
    let acc = [ p_capability decoder ] in

    let rec loop acc = match p_peek_char decoder with
      | Some ' ' ->
        p_junk_char decoder;
        let capability = p_capability decoder in
        loop (capability :: acc)
      | Some chr -> raise (Leave (err_unexpected_char chr decoder))
      | None -> List.rev acc
    in

    loop acc

  let p_first_ref decoder =
    let obj_id = p_hash decoder in
    p_space decoder;
    let refname = Cstruct.to_string (p_while0 not_null decoder) in
    p_null decoder;
    let capabilities =match p_peek_char decoder with
      | Some ' ' ->
        p_junk_char decoder;
        p_capabilities1 decoder
      | Some _ ->
        p_capabilities1 decoder
      | None -> raise (Leave (err_unexpected_end_of_input decoder))
    in

    if Hash.equal obj_id zero_id
    && refname = "capabilities^{}"
    then `NoRef capabilities
    else `Ref ((obj_id, refname, false), capabilities)

  let shallow decoder =
    let _ = p_string "shallow" decoder in
    p_space decoder;
    let obj_id = p_hash decoder in
    obj_id

  let unshallow decoder =
    let _ = p_string "unshallow" decoder in
    p_space decoder;
    let obj_id = p_hash decoder in
    obj_id

  let other_ref decoder =
    let obj_id = p_hash decoder in
    p_space decoder;
    let refname = Cstruct.to_string (p_while0 (function '^' -> false | _ -> true) decoder) in

    let peeled = match p_peek_char decoder with
      | Some '^' ->
        p_char '^' decoder;
        p_char '{' decoder;
        p_char '}' decoder;
        true
      | Some chr -> raise (Leave (err_unexpected_char chr decoder))
      | None -> false
    in

    (obj_id, refname, peeled)

  type advertised_refs =
    { shallow      : Hash.t list
    ; refs         : (Hash.t * string * bool) list
    ; capabilities : capability list }

  let pp_advertised_refs fmt { shallow; refs; capabilities; } =
    let sep fmt () = Format.fprintf fmt ";@ " in
    let pp_ref fmt (hash, refname, peeled) =
      match peeled with
      | true -> Format.fprintf fmt "%a %s^{}" Hash.pp hash refname
      | false -> Format.fprintf fmt "%a %s" Hash.pp hash refname
    in

    Format.fprintf fmt "{ @[<hov>shallow = [ @[<hov>%a@] ];@ \
                                 refs = [ @[<hov>%a@] ];@ \
                                 capabilites = [ @[<hov>%a@] ]; }"
      (pp_list ~sep Hash.pp) shallow
      (pp_list ~sep pp_ref) refs
      (pp_list ~sep pp_capability) capabilities

  let rec p_advertised_refs ~pkt ~first ~shallow_state refs decoder =
    match pkt with
    | `Flush ->
      p_return refs decoder
    | `Empty -> raise (Leave (err_unexpected_empty_pkt_line decoder))
    | `Malformed -> raise (Leave (err_malformed_pkt_line decoder))
    | `Line _ ->
      match p_peek_char decoder with
      | Some 's' ->
        let rest = shallow decoder in
        p_pkt_line (p_advertised_refs
                      ~first:true
                      ~shallow_state:true
                      { refs with shallow = rest :: refs.shallow })
          decoder
      | Some _ when shallow_state = false ->
        if first = false
        then match p_first_ref decoder with
          | `NoRef capabilities ->
            p_pkt_line (p_advertised_refs
                          ~first:true
                          ~shallow_state:false
                          { refs with capabilities })
              decoder
          | `Ref (first, capabilities) ->
            p_pkt_line (p_advertised_refs
                          ~first:true
                          ~shallow_state:false
                          { refs with capabilities
                                    ; refs = [ first ] })
              decoder
        else let rest = other_ref decoder in
          p_pkt_line (p_advertised_refs
                        ~first:true
                        ~shallow_state:false
                        { refs with refs = rest :: refs.refs })
            decoder
      | Some chr -> raise (Leave (err_unexpected_char chr decoder))
      | None -> raise (Leave (err_unexpected_end_of_input decoder))

  let p_advertised_refs decoder =
    p_pkt_line
      (p_advertised_refs
         ~first:false
         ~shallow_state:false
         { shallow = []
         ; refs = []
         ; capabilities = [] })
      decoder

  type shallow_update =
    { shallow   : Hash.t list
    ; unshallow : Hash.t list }

  let pp_shallow_update fmt { shallow; unshallow; } =
    let sep fmt () = Format.fprintf fmt ";@ " in

    Format.fprintf fmt "{ @[<hov>shallow = [ @[<hov>%a@] ];@ \
                                 unshallow = [ @[<hov>%a@] ];@] }"
      (pp_list ~sep Hash.pp) shallow
      (pp_list ~sep Hash.pp) unshallow

  let rec p_shallow_update ~pkt lst decoder = match pkt with
    | `Flush -> p_return lst decoder
    | `Empty -> raise (Leave (err_unexpected_empty_pkt_line decoder))
    | `Malformed -> raise (Leave (err_malformed_pkt_line decoder))
    | `Line _ -> match p_peek_char decoder with
      | Some 's' ->
        let x = shallow decoder in
        p_pkt_line (p_shallow_update { lst with shallow = x :: lst.shallow }) decoder
      | Some 'u' ->
        let x = unshallow decoder in
        p_pkt_line (p_shallow_update { lst with unshallow = x :: lst.unshallow }) decoder
      | Some chr -> raise (Leave (err_unexpected_char chr decoder))
      | None -> raise (Leave (err_unexpected_end_of_input decoder))

  let p_shallow_update decoder =
    p_pkt_line (p_shallow_update { shallow = []
                                 ; unshallow = [] })
      decoder

  let multi_ack_detailed decoder =
    ignore @@ p_string "ACK" decoder;
    p_space decoder;
    let hash = p_hash decoder in

    let detail = match p_peek_char decoder with
      | None -> raise (Leave (err_unexpected_end_of_input decoder))
      | Some ' ' ->
        p_junk_char decoder;
        (match p_peek_char decoder with
         | Some 'r' ->
           ignore @@ p_string "ready" decoder;
           `Ready
         | Some 'c' ->
           ignore @@ p_string "common" decoder;
           `Common
         | Some chr -> raise (Leave (err_unexpected_char chr decoder))
         | None -> raise (Leave (err_unexpected_end_of_input decoder)))
      | Some chr -> raise (Leave (err_unexpected_char chr decoder))
    in

    hash, detail

  let multi_ack decoder =
    ignore @@ p_string "ACK" decoder;
    p_space decoder;
    let hash = p_hash decoder in
    p_space decoder;
    ignore @@ p_string "continue" decoder;

    hash

  let ack decoder =
    ignore @@ p_string "ACK" decoder;
    p_space decoder;
    let hash = p_hash decoder in

    hash

  type acks =
    { shallow   : Hash.t list
    ; unshallow : Hash.t list
    ; acks      : (Hash.t * [ `Common | `Ready | `Continue | `ACK ]) list }

  let pp_ack fmt (hash, detail) =
    let pp_detail fmt = function
      | `Common -> Format.fprintf fmt "`Common"
      | `Ready -> Format.fprintf fmt "`Ready"
      | `Continue -> Format.fprintf fmt "`Continue"
      | `ACK -> Format.fprintf fmt "`ACK"
    in

    Format.fprintf fmt "(%a, %a)" Hash.pp hash pp_detail detail

  let pp_acks fmt { shallow; unshallow; acks; } =
    let sep fmt () = Format.fprintf fmt ";@ " in

    Format.fprintf fmt "{ @[<hov>shallow = [ @[<hov>%a@] ];@ \
                                 unshallow = [ @[<hov>%a@] ];@ \
                                 acks = [ @[<hov>%a@] ];@] }"
      (pp_list ~sep Hash.pp) shallow
      (pp_list ~sep Hash.pp) unshallow
      (pp_list ~sep pp_ack) acks

  let rec p_negociation ~pkt ~mode lst decoder = match pkt with
    | `Flush -> raise (Leave (err_unexpected_flush_pkt_line decoder))
    | `Empty -> raise (Leave (err_unexpected_empty_pkt_line decoder))
    | `Malformed -> raise (Leave (err_malformed_pkt_line decoder))
    | `Line _ ->
      match p_peek_char decoder, mode with
      | Some 's', _ ->
        let x = shallow decoder in
        p_pkt_line (p_negociation ~mode { lst with shallow = x :: lst.shallow }) decoder
      | Some 'u', _ ->
        let x = unshallow decoder in
        p_pkt_line (p_negociation ~mode { lst with unshallow = x :: lst.unshallow }) decoder
      | Some 'A', `Multi_ack_detailed ->
        let (hash, detail) = multi_ack_detailed decoder in

        p_pkt_line (p_negociation ~mode { lst with acks = (hash, detail) :: lst.acks }) decoder
      | Some 'A', `Multi_ack ->
        let hash = multi_ack decoder in

        p_pkt_line (p_negociation ~mode { lst with acks = (hash, `Continue) :: lst.acks }) decoder
      | Some 'A', `Ack ->
        let hash = ack decoder in

        p_return { lst with acks = [ (hash, `ACK) ] } decoder
      | Some 'N', (`Multi_ack | `Multi_ack_detailed) ->
        ignore @@ p_string "NAK" decoder;

        p_return { lst with acks = List.rev lst.acks } decoder
      | Some 'N', `Ack ->
        ignore @@ p_string "NAK" decoder;

        p_return { lst with acks = List.rev lst.acks } decoder
      | Some chr, _ -> raise (Leave (err_unexpected_char chr decoder))
      | None, _ -> raise (Leave (err_unexpected_end_of_input decoder))

  let p_negociation ~mode decoder =
    p_pkt_line (p_negociation ~mode { shallow = []
                                    ; unshallow = []
                                    ; acks = [] }) decoder

  type negociation_result =
    | NAK
    | ACK of Hash.t
    | ERR of string

  let pp_negociation_result fmt = function
    | NAK -> Format.fprintf fmt "NAK"
    | ACK hash -> Format.fprintf fmt "(ACK %a)" Hash.pp hash
    | ERR err -> Format.fprintf fmt "(ERR %s)" err

  let p_negociation_result ~pkt decoder = match pkt with
    | `Flush -> raise (Leave (err_unexpected_flush_pkt_line decoder))
    | `Empty -> raise (Leave (err_unexpected_empty_pkt_line decoder))
    | `Malformed -> raise (Leave (err_malformed_pkt_line decoder))
    | `Line _ ->
      match p_peek_char decoder with
      | Some 'N' ->
        ignore @@ p_string "NAK" decoder;
        p_return NAK decoder
      | Some 'A' ->
        ignore @@ p_string "ACK" decoder;
        p_space decoder;
        let hash = p_hash decoder in
        p_return (ACK hash) decoder
      | Some 'E' ->
        ignore @@ p_string "ERR" decoder;
        p_space decoder;
        let msg = Cstruct.to_string @@ p_while1 (fun _ -> true) decoder in
        p_return (ERR msg) decoder
      | Some chr -> raise (Leave (err_unexpected_char chr decoder))
      | None -> raise (Leave (err_unexpected_end_of_input decoder))

  let p_negociation_result decoder =
    p_pkt_line p_negociation_result decoder

  type pack =
    [ `Raw of Cstruct.t
    | `Out of Cstruct.t
    | `Err of Cstruct.t ]

  let p_pack ~pkt ~mode decoder = match pkt, mode with
    | `Malformed, _ -> raise (Leave (err_malformed_pkt_line decoder))
    | `Empty, _ -> raise (Leave (err_unexpected_empty_pkt_line decoder))
    | `Line n, `No_multiplexe ->
      let raw = Cstruct.sub decoder.buffer decoder.pos n in
      decoder.pos <- decoder.pos + n;
      p_return (`Raw raw) decoder
    | `Flush, _ -> p_return `End decoder
    | `Line n, (`Side_band_64k | `Side_band) ->
      let raw = Cstruct.sub decoder.buffer (decoder.pos + 1) (n - 1) in

      match p_peek_char decoder with
      | Some '\001' -> decoder.pos <- decoder.pos + n; p_return (`Raw raw) decoder
      | Some '\002' -> decoder.pos <- decoder.pos + n; p_return (`Out raw) decoder
      | Some '\003' -> decoder.pos <- decoder.pos + n; p_return (`Err raw) decoder
      | Some chr -> raise (Leave (err_unexpected_char chr decoder))
      | None -> raise (Leave (err_unexpected_end_of_input decoder))

  let p_pack ~mode decoder =
    p_pkt_line ~strict:true (p_pack ~mode) decoder

  type report_status =
    { unpack   : (unit, string) result
    ; commands : (string, string * string) result list }

  let pp_result (type a) (type b)
      (pp_ok : Format.formatter -> 'a -> unit)
      (pp_err : Format.formatter -> 'b -> unit)
      fmt
      (value : ('a, 'b) result)
    = match value with
    | Ok v -> Format.fprintf fmt "(Ok @[<hov>%a@])" pp_ok v
    | Error err -> Format.fprintf fmt "(Error @[<hov>%a@])" pp_err err

  let pp_report_status fmt { unpack; commands; } =
    let pp_unit fmt ()   = Format.fprintf fmt "()" in
    let pp_string fmt s  = Format.fprintf fmt "%S" s in
    let sep fmt ()       = Format.fprintf fmt ";@ " in
    let pp_refname fmt r = Format.fprintf fmt "%s" r in
    let pp_pair pp_a pp_b fmt (a, b) =
      Format.fprintf fmt "(@[<hov>[@<hov>%a], @[<hov>%a@]@])"
        pp_a a pp_b b
    in

    let pp_command fmt command =
      pp_result pp_refname (pp_pair pp_refname pp_string) fmt command
    in

    Format.fprintf fmt "{ @[<hov>unpack = @[<hov>%a@];@ \
                                 commands = [ @[<hov>%a@] ];@] }"
      (pp_result pp_unit pp_string) unpack
      (pp_list ~sep pp_command) commands

  let p_unpack decoder : (unit, string) result =
    ignore @@ p_string "unpack" decoder;
    p_space decoder;
    let msg = p_while1 (fun _ -> true) decoder in
    match Cstruct.to_string msg with
    | "ok" -> Ok ()
    | err  -> (Error err)

  let p_command_status decoder : (string, string * string) result =
    let status = p_while1 (function ' ' -> false | _ -> true) decoder in
    match Cstruct.to_string status with
    | "ok" ->
      p_space decoder;
      let refname = p_while1 (fun _ -> true) decoder |> Cstruct.to_string in
      Ok refname
    | "ng" ->
      p_space decoder;
      let refname = p_while1 (function ' ' -> false | _ -> true) decoder |> Cstruct.to_string in
      p_space decoder;
      let msg = p_while1 (fun _ -> true) decoder |> Cstruct.to_string in
      Error (refname, msg)
    | _ -> raise (Leave (err_unexpected_char '\000' decoder))

  let rec p_report_status ~pkt ~unpack ~commands ~sideband decoder =
    let go unpack commands sideband decoder =
      match p_peek_char decoder with
      | Some 'u' ->
        let unpack = p_unpack decoder in
        p_pkt_line (p_report_status ~unpack:(Some unpack) ~commands ~sideband) decoder
      | Some ('o' | 'n') ->
        let command = p_command_status decoder in
        let commands = match commands with
          | Some lst -> Some (command :: lst)
          | None -> Some [ command ]
        in

        p_pkt_line (p_report_status ~unpack ~commands ~sideband) decoder
      | Some chr -> raise (Leave (err_unexpected_char chr decoder))
      | None -> raise (Leave (err_unexpected_end_of_input decoder))
    in

    match pkt, sideband, unpack, commands with
    | `Malformed, _, _, _ -> raise (Leave (err_malformed_pkt_line decoder))
    | `Flush, _, Some unpack, Some (_ :: _ as commands) -> p_return { unpack; commands; } decoder
    | `Flush, _, _, _ -> raise (Leave (err_unexpected_flush_pkt_line decoder))
    | `Empty, _, _, _ -> raise (Leave (err_unexpected_empty_pkt_line decoder))
    | `Line _, (`Side_band | `Side_band_64k), _, _ ->
      (match p_peek_char decoder with
       | Some '\001' ->
         p_junk_char decoder;
         go unpack commands sideband decoder
       | Some '\002' ->
         ignore @@ p_while0 (fun _ -> true) decoder;
         p_pkt_line (p_report_status ~unpack ~commands ~sideband) decoder
       | Some '\003' ->
         ignore @@ p_while0 (fun _ -> true) decoder;
         p_pkt_line (p_report_status ~unpack ~commands ~sideband) decoder
       | Some chr -> raise (Leave (err_unexpected_char chr decoder))
       | None -> raise (Leave (err_unexpected_empty_pkt_line decoder)))
    | `Line _, `No_multiplexe, _, _ ->
      go unpack commands sideband decoder

  let p_report_status sideband decoder =
    p_pkt_line (p_report_status ~unpack:None ~commands:None ~sideband) decoder

  (* XXX(dinosaure): désolé mais ce GADT, c'est quand même la classe. *)
  type _ transaction =
    | ReferenceDiscovery : advertised_refs transaction
    | ShallowUpdate      : shallow_update transaction
    | Negociation        : ack_mode -> acks transaction
    | NegociationResult  : negociation_result transaction
    | PACK               : side_band -> flow transaction
    | ReportStatus       : side_band -> report_status transaction
  and ack_mode =
    [ `Ack | `Multi_ack | `Multi_ack_detailed ]
  and flow =
    [ `Raw of Cstruct.t | `End | `Err of Cstruct.t | `Out of Cstruct.t ]
  and side_band =
    [ `Side_band | `Side_band_64k | `No_multiplexe ]

  let decode
    : type result. decoder -> result transaction -> result state
    = fun decoder -> function
    | ReferenceDiscovery    -> p_safe p_advertised_refs decoder
    | ShallowUpdate         -> p_safe p_shallow_update decoder
    | Negociation ackmode   -> p_safe (p_negociation ~mode:ackmode) decoder
    | NegociationResult     -> p_safe p_negociation_result decoder
    | PACK sideband         -> p_safe (p_pack ~mode:sideband) decoder
    | ReportStatus sideband -> p_safe (p_report_status sideband) decoder

  let decoder () =
    { buffer = Cstruct.create 65535
    ; pos    = 0
    ; max    = 0
    ; eop    = None }
end

module Encoder (Digest : Ihash.IDIGEST with type t = Bytes.t)
  : ENCODER with type Hash.t = Digest.t
             and module Digest = Digest =
struct
  module Digest = Digest
  module Hash = Helper.BaseBytes

  type encoder =
    { mutable payload : Cstruct.t
    ; mutable pos     : int }

  let set_pos encoder pos =
    encoder.pos <- pos

  let free { payload; pos; } =
    Cstruct.sub payload pos (Cstruct.len payload - pos)

  type 'a state =
    | Write of { buffer   : Cstruct.t
               ; off      : int
               ; len      : int
               ; continue : int -> 'a state }
    | Ok of 'a

  let flush k encoder =
    if encoder.pos > 0
    then let rec k1 n =
           if n < encoder.pos
           then Write { buffer = encoder.payload
                      ; off = n
                      ; len = encoder.pos - n
                      ; continue = fun m -> k1 (n + m) }
           else begin
             encoder.pos <- 4;
             k encoder
           end
      in
      k1 0
    else
      k encoder

  let writes s k encoder =
    let _len = Cstruct.len encoder.payload in
    let go j l encoder =
      let rem = _len - encoder.pos in
      let len = if l > rem then rem else l in
      Cstruct.blit_from_string s j encoder.payload encoder.pos len;
      encoder.pos <- encoder.pos + len;
      if len < l
      then raise (Invalid_argument "PKT Format: payload upper than 65520 bytes")
      else k encoder
    in
    go 0 (String.length s) encoder

  let w_lf k e = writes "\n" k e

  let noop k encoder = k encoder

  let pkt_line ?(lf = false) writes k encoder =
    let pkt_len encoder =
      let has = encoder.pos in
      let hdr = Format.sprintf "%04x" has in

      Cstruct.blit_from_string hdr 0 encoder.payload 0 4;
      flush k encoder
    in

    writes ((if lf then w_lf else noop) @@ pkt_len) encoder

  let pkt_flush k encoder =
    Cstruct.blit_from_string "0000" 0 encoder.payload 0 4;
    flush k encoder

  let hash_to_hex_string x =
    Helper.BaseBytes.to_hex x |> Bytes.to_string

  let zero_id = Bytes.make Digest.length '\000'

  let w_space k encoder =
    writes " " k encoder

  let w_null k encoder =
    writes "\000" k encoder

  let w_capabilities lst k encoder =
    let rec loop lst encoder = match lst with
      | [] -> k encoder
      | [ x ] -> writes (string_of_capability x) k encoder
      | x :: r ->
        (writes (string_of_capability x)
         @@ w_space
         @@ loop r)
        encoder
    in

    loop lst encoder

  let w_hash hash k encoder =
    writes (hash_to_hex_string hash) k encoder

  let w_first_want obj_id capabilities k encoder =
    (writes "want"
     @@ w_space
     @@ w_hash obj_id
     @@ w_space
     @@ w_capabilities capabilities k)
      encoder

  let w_want obj_id k encoder =
    (writes "want"
     @@ w_space
     @@ w_hash obj_id k)
      encoder

  let w_shallow obj_id k encoder =
    (writes "shallow"
     @@ w_space
     @@ w_hash obj_id k)
      encoder

  let w_deepen depth k encoder =
    (writes "deepen"
     @@ w_space
     @@ writes (Format.sprintf "%d" depth) k)
      encoder

  let w_deepen_since timestamp k encoder =
    (writes "deepen-since"
     @@ w_space
     @@ writes (Format.sprintf "%Ld" timestamp) k)
      encoder

  let w_deepen_not refname k encoder =
    (writes "deepen-not"
     @@ w_space
     @@ writes refname k)
      encoder

  let w_first_want obj_id capabilities k encoder =
    pkt_line (w_first_want obj_id capabilities) k encoder
  let w_want obj_id k encoder =
    pkt_line (w_want obj_id) k encoder
  let w_shallow obj_id k encoder =
    pkt_line (w_shallow obj_id) k encoder
  let w_deepen depth k encoder =
    pkt_line (w_deepen depth) k encoder
  let w_deepen_since timestamp k encoder =
    pkt_line (w_deepen_since timestamp) k encoder
  let w_deepen_not refname k encoder =
    pkt_line (w_deepen_not refname) k encoder

  type upload_request =
    { want         : Hash.t * Hash.t list
    ; capabilities : capability list
    ; shallow      : Hash.t list
    ; deep         : [ `Depth of int | `Timestamp of int64 | `Ref of string ] option }

  let w_list w l k encoder =
    let rec aux l encoder = match l with
      | [] -> k encoder
      | x :: r ->
        w x (aux r) encoder
    in
    aux l encoder

  let w_upload_request upload_request k encoder =
    let first, rest = upload_request.want in

    (w_first_want first upload_request.capabilities
     @@ (w_list w_want rest)
     @@ (w_list w_shallow upload_request.shallow)
     @@ (match upload_request.deep with
         | Some (`Depth depth)  -> w_deepen depth
         | Some (`Timestamp t) -> w_deepen_since t
         | Some (`Ref refname)  -> w_deepen_not refname
         | None -> noop)
     @@ pkt_flush k)
      encoder

  let w_flush k encoder =
    pkt_flush k encoder

  type request_command =
    [ `UploadPack
    | `ReceivePack
    | `UploadArchive ]

  type git_proto_request =
    { pathname        : string
    ; host            : (string * int option) option
    ; request_command : request_command }

  let w_request_command request_command k encoder = match request_command with
    | `UploadPack    -> writes "git-upload-pack"    k encoder
    | `ReceivePack   -> writes "git-receive-pack"   k encoder
    | `UploadArchive -> writes "git-upload-archive" k encoder

  let w_git_proto_request git_proto_request k encoder =
    let w_host host k encoder = match host with
      | Some (host, Some port) ->
        (writes "host="
         @@ writes host
         @@ writes ":"
         @@ writes (Format.sprintf "%d" port)
         @@ w_null k)
          encoder
      | Some (host, None) ->
        (writes "host="
         @@ writes host
         @@ w_null k)
          encoder
      | None -> noop k encoder
    in

    (w_request_command git_proto_request.request_command
     @@ w_space
     @@ writes git_proto_request.pathname
     @@ w_null
     @@ w_host git_proto_request.host k)
      encoder

  let w_done k encoder = pkt_line (writes "done") k encoder
  let w_has hash k encoder =
    (writes "have"
     @@ w_space
     @@ w_hash hash k)
      encoder

  let w_has hash k encoder = pkt_line (w_has hash) k encoder

  let w_has l k encoder =
    let rec go l encoder = match l with
      | [] -> w_flush k encoder
      | x :: r ->
        (w_has x @@ go r) encoder
    in
    go l encoder

  let w_git_proto_request git_proto_request k encoder =
    pkt_line (w_git_proto_request git_proto_request) k encoder

  let w_shallow l k encoder =
    let rec go l encoder = match l with
      | [] -> k encoder
      | x :: r ->
        pkt_line
          (fun k -> writes "shallow"
            @@ w_space
            @@ w_hash x k)
          (go r)
          encoder
    in

    go l encoder

  type ('a, 'b) either =
    | L of 'a
    | R of 'b
  type update_request =
    { shallow      : Hash.t list
    ; requests     : (command * command list, push_certificate) either
    ; capabilities : capability list }
  and command =
    | Create of Hash.t * string (* XXX(dinosaure): break the dependence with [Store] and consider the reference name as a string. *)
    | Delete of Hash.t * string
    | Update of Hash.t * Hash.t * string
  and push_certificate =
    { pusher   : string
    ; pushee   : string (* XXX(dinosaure): the repository url anonymized. *)
    ; nonce    : string
    ; options  : string list
    ; commands : command list
    ; gpg      : string list }

  let w_command command k encoder =
    match command with
    | Create (hash, refname) ->
      (w_hash zero_id
       @@ w_space
       @@ w_hash hash
       @@ w_space
       @@ writes refname k)
        encoder
    | Delete (hash, refname) ->
      (w_hash hash
       @@ w_space
       @@ w_hash zero_id
       @@ w_space
       @@ writes refname k)
        encoder
    | Update (old_id, new_id, refname) ->
      (w_hash old_id
       @@ w_space
       @@ w_hash new_id
       @@ w_space
       @@ writes refname k)
        encoder

  let w_first_command capabilities first k encoder =
    (w_command first
     @@ w_null
     @@ w_capabilities capabilities k)
      encoder

  let w_first_command capabilities first k encoder =
    pkt_line (w_first_command capabilities first) k encoder

  let w_command command k encoder =
    pkt_line (w_command command) k encoder

  let w_commands capabilities (first, rest) k encoder =
    (w_first_command capabilities first
     @@ w_list w_command rest
     @@ pkt_flush k)
      encoder

  let w_push_certificates capabilities push_cert k encoder =
    (* XXX(dinosaure): clean this code, TODO! *)

    ((fun k e -> pkt_line ~lf:true (fun k -> writes "push-cert" @@ w_null @@ w_capabilities capabilities k) k e)
     @@ (fun k e -> pkt_line ~lf:true (writes "certificate version 0.1") k e)
     @@ (fun k e -> pkt_line ~lf:true (fun k -> writes "pusher" @@ w_space @@ writes push_cert.pusher k) k e)
     @@ (fun k e -> pkt_line ~lf:true (fun k -> writes "pushee" @@ w_space @@ writes push_cert.pushee k) k e)
     @@ (fun k e -> pkt_line ~lf:true (fun k -> writes "nonce" @@ w_space @@ writes push_cert.nonce k) k e)
     @@ (fun k e -> w_list (fun x k e -> pkt_line ~lf:true (fun k -> writes "push-option" @@ w_space @@ writes x k) k e) push_cert.options k e)
     @@ (fun k e -> pkt_line ~lf:true noop k e)
     @@ (fun k e -> w_list (fun x k e -> pkt_line ~lf:true (w_command x) k e) push_cert.commands k e)
     @@ (fun k e -> w_list (fun x k e -> pkt_line ~lf:true (writes x) k e) push_cert.gpg k e)
     @@ (fun k e -> pkt_line ~lf:true (writes "push-cert-end") k e)
     @@ pkt_flush
     @@ k)
    encoder

  let w_update_request update_request k encoder =
    (w_shallow update_request.shallow
     @@ (match update_request.requests with
         | L commands  -> w_commands update_request.capabilities commands
         | R push_cert -> w_push_certificates update_request.capabilities push_cert)
     @@ k)
      encoder

  let flush_pack k encoder =
    if encoder.pos > 0
    then let rec k1 n =
           if n < encoder.pos
           then Write { buffer = encoder.payload
                      ; off = n
                      ; len = encoder.pos - n
                      ; continue = fun m -> k1 (n + m) }
           else begin
             encoder.pos <- 0;
             k encoder
           end
      in
      k1 0
    else
      k encoder

  let w_pack n k encoder =
    encoder.pos <- encoder.pos + n;
    flush_pack k encoder

  type action =
    [ `GitProtoRequest of git_proto_request
    | `UploadRequest of upload_request
    | `UpdateRequest of update_request
    | `Has of Hash.t list
    | `Done
    | `Flush
    | `PACK of int
    | `Shallow of Hash.t list ]

  let encode encoder = function
    | `GitProtoRequest c -> w_git_proto_request c (fun encoder -> Ok ()) encoder
    | `UploadRequest i   -> w_upload_request i (fun encoder -> Ok ()) encoder
    | `UpdateRequest i   -> w_update_request i (fun encoder -> Ok ()) encoder
    | `Has l             -> w_has l (fun encoder -> Ok ()) encoder
    | `Done              -> w_done (fun encoder -> Ok ()) encoder
    | `Flush             -> w_flush (fun encoder -> Ok ()) encoder
    | `Shallow l         -> w_shallow l (fun encoder -> Ok ()) encoder
    | `PACK n            -> w_pack n (fun encoder -> Ok ()) encoder

  let encoder () =
    { payload = Cstruct.create 65535
    ; pos     = 4 }
end

module Client (Digest : Ihash.IDIGEST with type t = Bytes.t)
  : CLIENT with type Hash.t = Digest.t
            and module Digest = Digest =
struct
  module Decoder = Decoder(Digest)
  module Encoder = Encoder(Digest)

  module Digest = Digest
  module Hash   = Helper.BaseBytes

  type context =
    { decoder      : Decoder.decoder
    ; encoder      : Encoder.encoder
    ; mutable capabilities : capability list }

  let capabilities { capabilities; _ } = capabilities
  let set_capabilities context capabilities =
    context.capabilities <- capabilities

  let encode x k ctx =
    let rec loop = function
      | Encoder.Write { buffer; off; len; continue; } ->
        `Write (buffer, off, len, fun n -> loop (continue n))
      | Encoder.Ok () -> k ctx
    in
    loop (Encoder.encode ctx.encoder x)

  let decode phase k ctx =
    let rec loop = function
      | Decoder.Ok v -> k v ctx
      | Decoder.Read { buffer; off; len; continue; } ->
        `Read (buffer, off, len, fun n -> loop (continue n))
      | Decoder.Error { err; buf; committed; } ->
        `Error (err, buf, committed)
    in
    loop (Decoder.decode ctx.decoder phase)

  type result =
    [ `Refs of Decoder.advertised_refs
    | `ShallowUpdate of Decoder.shallow_update
    | `Negociation of Decoder.acks
    | `NegociationResult of Decoder.negociation_result
    | `PACK of Decoder.flow
    | `Flush
    | `Nothing
    | `ReadyPACK of Cstruct.t
    | `ReportStatus of Decoder.report_status ]

  type process =
    [ `Read  of (Cstruct.t * int * int * (int -> process ))
    | `Write of (Cstruct.t * int * int * (int -> process))
    | `Error of (Decoder.error * Cstruct.t * int)
    | result ]

  let pp_result fmt = function
    | `Refs refs ->
      Format.fprintf fmt "(`Refs @[<hov>%a@])" Decoder.pp_advertised_refs refs
    | `ShallowUpdate shallow_update ->
      Format.fprintf fmt "(`ShallowUpdate @[<hov>%a@])" Decoder.pp_shallow_update shallow_update
    | `Negociation acks ->
      Format.fprintf fmt "(`Negociation [ @[<hov>%a@] ])"
        Decoder.pp_acks acks
    | `NegociationResult result ->
      Format.fprintf fmt "(`NegociationResult @[<hov>%a@])" Decoder.pp_negociation_result result
    | `PACK (`Err _) ->
      Format.fprintf fmt "(`Pack stderr)"
    | `PACK (`Out _) ->
      Format.fprintf fmt "(`Pack stdout)"
    | `PACK (`Raw _) ->
      Format.fprintf fmt "(`Pack pack)"
    | `PACK `End ->
      Format.fprintf fmt "(`Pack `End)"
    | `Flush ->
      Format.fprintf fmt "`Flush"
    | `Nothing ->
      Format.fprintf fmt "`Nothing"
    | `ReadyPACK raw ->
      Format.fprintf fmt "(`ReadyPACK #raw)"
    | `ReportStatus status ->
      Format.fprintf fmt "(`ReportStatus @[<hov>%a@])" Decoder.pp_report_status status

  type action =
    [ `GitProtoRequest of Encoder.git_proto_request
    | `Shallow of Hash.t list
    | `UploadRequest of Encoder.upload_request
    | `UpdateRequest of Encoder.update_request
    | `Has of Hash.t list
    | `Done
    | `Flush
    | `ReceivePACK
    | `SendPACK of int
    | `FinishPACK ]

  let run context = function
    | `GitProtoRequest c ->
      encode
        (`GitProtoRequest c)
        (decode Decoder.ReferenceDiscovery
           (fun refs ctx ->
              ctx.capabilities <- refs.Decoder.capabilities;
              `Refs refs))
        context
    | `Flush ->
      encode `Flush (fun context -> `Flush) context
    | `UploadRequest (descr : Encoder.upload_request) ->
      let common = List.filter (fun x -> List.exists ((=) x) context.capabilities) descr.Encoder.capabilities in
      (* XXX(dinosaure): we update with the shared capabilities between the
         client and the server. *)

      context.capabilities <- common;

      let next = match descr.Encoder.deep with
        | Some (`Depth n) ->
          if n > 0
          then decode Decoder.ShallowUpdate (fun shallow_update context -> `ShallowUpdate shallow_update)
          else (fun context -> `ShallowUpdate { Decoder.shallow = []; unshallow = []; })
        | _ -> (fun context -> `ShallowUpdate { Decoder.shallow = []; unshallow = []; })
      in
      encode (`UploadRequest descr) next context
    | `UpdateRequest (descr : Encoder.update_request) ->
      let common = List.filter (fun x -> List.exists ((=) x) context.capabilities) descr.Encoder.capabilities in

      (* XXX(dinosaure): same as below. *)

      context.capabilities <- common;

      encode (`UpdateRequest descr) (fun { encoder; _ } ->
          Encoder.set_pos encoder 0;
          let raw = Encoder.free encoder in

          `ReadyPACK raw) context
    | `Has has ->
      let ackmode =
        if List.exists ((=) `Multi_ack_detailed) context.capabilities
        then `Multi_ack_detailed
        else if List.exists ((=) `Multi_ack) context.capabilities
        then `Multi_ack
        else `Ack
      in

      encode (`Has has) (decode (Decoder.Negociation ackmode) (fun status context -> `Negociation status)) context
    | `Done ->
      encode `Done (decode Decoder.NegociationResult (fun result context -> `NegociationResult result)) context
    | `ReceivePACK ->
      let sideband =
        if List.exists ((=) `Side_band_64k) context.capabilities
        then `Side_band_64k
        else if List.exists ((=) `Side_band) context.capabilities
        then `Side_band
        else `No_multiplexe
      in
      (decode (Decoder.PACK sideband) (fun flow context -> `PACK flow)) context
    | `SendPACK w ->
      encode (`PACK w)
        (fun { encoder; _ } ->
          Encoder.set_pos encoder 0;
          let raw = Encoder.free encoder in

          `ReadyPACK raw)
        context
    | `FinishPACK ->
      let sideband =
        if List.exists ((=) `Side_band_64k) context.capabilities
        then `Side_band_64k
        else if List.exists ((=) `Side_band) context.capabilities
        then `Side_band
        else `No_multiplexe
      in

      if List.exists ((=) `Report_status) context.capabilities
      then decode (Decoder.ReportStatus sideband) (fun result context -> `ReportStatus result) context
      else `Nothing
    (* XXX(dinosaure): the specification does not explain what the server send
       when we don't have the capability [report-status]. *)
    | `Shallow l ->
      encode (`Shallow l) (fun context -> `Nothing) context

  let context c =
    let context =
      { decoder = Decoder.decoder ()
      ; encoder = Encoder.encoder ()
      ; capabilities = [] }
    in

    context, (* encode (`GitProtoRequest c) *)
      (decode Decoder.ReferenceDiscovery
         (fun refs ctx ->
            ctx.capabilities <- refs.Decoder.capabilities;
            `Refs refs))
      context
end

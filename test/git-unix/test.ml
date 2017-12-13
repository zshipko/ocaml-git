(*
 * Copyright (c) 2013-2017 Thomas Gazagnaire <thomas@gazagnaire.org>
 * and Romain Calascibetta <romain.calascibetta@gmail.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Test_common

module TCP (Store: Git.S) = Test_sync.Make(struct
    module M = Git_unix.Sync(Store)
    module Store = M.Store
    type error = M.error
    let clone t ~reference uri = M.clone t ~reference uri
    let fetch_all t uri = M.fetch_all t uri
    let update t ~reference uri = M.update t ~reference uri
  end)

(* XXX(dinosaure): the divergence between the TCP API and the HTTP API
   will be update for an homogenization. *)

module HTTP (Store: Git.S) = Test_sync.Make(struct
    module M = Git_unix.HTTP(Store)
    module Store = M.Store
    type error = M.error
    let clone t ~reference uri = M.clone t ~reference:(reference, reference) uri

    exception Jump of Store.Ref.error

    let fetch_all t uri =
      let open Lwt.Infix in

      M.fetch_all t ~references:Store.Reference.Map.empty uri >>= function
      | Error _ as err -> Lwt.return err
      | Ok (_, _, downloaded) ->
        Lwt.try_bind
          (fun () -> Lwt_list.iter_s
              (fun (remote_ref, new_hash) ->
                 Store.Ref.write t remote_ref (Store.Reference.Hash new_hash) >>= function
                 | Ok () -> Lwt.return ()
                 | Error err -> Lwt.fail (Jump err))
              (Store.Reference.Map.bindings downloaded))
          (fun () -> Lwt.return (Ok ()))
          (function Jump err -> Lwt. return (Error (`Ref err))
                  | err -> Lwt.fail err)

    let update t ~reference uri =
      M.update_and_create t
        ~references:(Store.Reference.Map.singleton reference [ reference ])
        uri
  end)

module HTTPS (Store: Git.S) = Test_sync.Make(struct
    module M = Git_unix.HTTP(Store)
    module Store = M.Store
    type error = M.error
    let clone t ~reference uri = M.clone t ~reference:(reference, reference) uri

    exception Jump of Store.Ref.error

    let fetch_all t uri =
      let open Lwt.Infix in

      M.fetch_all t ~references:Store.Reference.Map.empty uri >>= function
      | Error _ as err -> Lwt.return err
      | Ok (_, _, downloaded) ->
        Lwt.try_bind
          (fun () -> Lwt_list.iter_s
              (fun (remote_ref, new_hash) ->
                 Store.Ref.write t remote_ref (Store.Reference.Hash new_hash) >>= function
                 | Ok () -> Lwt.return ()
                 | Error err -> Lwt.fail (Jump err))
              (Store.Reference.Map.bindings downloaded))
          (fun () -> Lwt.return (Ok ()))
          (function Jump err -> Lwt. return (Error (`Ref err))
                  | err -> Lwt.fail err)

    let update t ~reference uri =
      M.update_and_create t
        ~references:(Store.Reference.Map.singleton reference [ reference ])
        uri
  end)

module MemStore = Git.Mem.Store(Digestif.SHA1)
module FsStore = Git_unix.FS

let mem_backend =
  { name  = "mem"
  ; store = (module MemStore)
  ; shell = false }

let fs_backend =
  { name  = "unix"
  ; store = (module FsStore)
  ; shell = true }

module TCP1  = TCP(MemStore)
module TCP2  = TCP(FsStore)
module HTTP1 = HTTP(MemStore)
module HTTP2 = HTTPS(FsStore)

let () =
  verbose ();
  Alcotest.run "git-unix"
    [ Test_store.suite (`Quick, mem_backend)
    ; Test_store.suite (`Quick, fs_backend)
    ; TCP1.test_fetch "mem-local-tcp-sync" ["git://localhost/"]
    ; TCP1.test_clone "mem-remote-tcp-sync" [
        "git://github.com/mirage/ocaml-git.git", "master";
        "git://github.com/mirage/ocaml-git.git", "gh-pages";
      ]
    ; TCP2.test_fetch "fs-local-tcp-sync" ["git://localhost/"]
    ; TCP2.test_clone "fs-remote-tcp-sync" [
        "git://github.com/mirage/ocaml-git.git", "master";
        "git://github.com/mirage/ocaml-git.git", "gh-pages";
      ]
    ; HTTP1.test_clone "mem-http-sync" [
        "http://github.com/mirage/ocaml-git.git", "gh-pages"
      ]
    ; HTTP2.test_clone "fs-https-sync" [
        "https://github.com/mirage/ocaml-git.git", "gh-pages"
      ]
    ]

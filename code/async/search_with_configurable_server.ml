open Core.Std
open Async.Std

(* part 1 *)
(* Generate a DuckDuckGo search URI from a query string *)
let query_uri ~server query =
  let base_uri =
    Uri.of_string (String.concat ["http://";server;"/?format=json"])
  in
  Uri.add_query_param base_uri ("q", [query])
(* part 2 *)
(* Extract the "Definition" or "Abstract" field from the DuckDuckGo results *)
let get_definition_from_json json =
  match Yojson.Safe.from_string json with
  | `Assoc kv_list ->
    let find key =
      begin match List.Assoc.find kv_list key with
      | None | Some (`String "") -> None
      | Some s -> Some (Yojson.Safe.to_string s)
      end
    in
    begin match find "Abstract" with
    | Some _ as x -> x
    | None -> find "Definition"
    end
  | _ -> None

(* Execute the DuckDuckGo search *)
let get_definition ~server word =
  Cohttp_async.Client.get (query_uri ~server word)
  >>= fun  (_, body) ->
  Pipe.to_list body
  >>| fun strings ->
  (word, get_definition_from_json (String.concat strings))

(* Print out a word/definition pair *)
let print_result (word,definition) =
  printf "%s\n%s\n\n%s\n\n"
    word
    (String.init (String.length word) ~f:(fun _ -> '-'))
    (match definition with
    | None -> "No definition found"
    | Some def ->
      String.concat ~sep:"\n"
        (Wrapper.wrap (Wrapper.make 70) def))

(* Run many searches in parallel, printing out the results after they're all
   done. *)
let search_and_print ~servers words =
  let servers = Array.of_list servers in
  Deferred.all (List.mapi words ~f:(fun i word ->
    let server = servers.(i mod Array.length servers) in
    get_definition ~server word))
  >>| fun results ->
  List.iter results ~f:print_result

let () =
  Command.async_basic
    ~summary:"Retrieve definitions from duckduckgo search engine"
    Command.Spec.(
      let string_list = Arg_type.create (String.split ~on:',') in
      empty
      +> anon (sequence ("word" %: string))
      +> flag "-servers"
           (optional_with_default ["api.duckduckgo.com"] string_list)
           ~doc:" Specify server to connect to"
    )
    (fun words servers () -> search_and_print ~servers words)
  |> Command.run

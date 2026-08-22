#!/usr/bin/env nu

def convert-path [src: path, dest: path] {
    let src_abs = ($src | path expand)
    let kind = ($src_abs | path type)

    if $kind == "dir" {
        mkdir $dest

        for file in (glob --no-dir ($src_abs | path join "**" "*")) {
            let file_abs = ($file | path expand)
            let rel = ($file_abs | path relative-to $src_abs)
            convert-file $file ($dest | path join $rel)
        }
    } else if $kind == "file" {
        convert-file $src_abs $dest
    }
}

def convert-file [src: path, dest: path] {
    mkdir ($dest | path dirname)

    if ($src | str lowercase | str ends-with ".fcstd") {
        let xml_dest = $"($dest).Document.xml"
        unzip -p $src Document.xml | save --force $xml_dest
    } else {
        cp $src $dest
    }
}

def main [left: path, right: path] {
    let temp = (mktemp -d)
    let left_converted = ($temp | path join "left")
    let right_converted = ($temp | path join "right")

    convert-path $left $left_converted
    convert-path $right $right_converted

    let diff = (
        ^git diff --no-index --no-ext-diff --color=always -- $left_converted $right_converted
        | complete
    )

    print --raw --no-newline $diff.stdout
    print --raw --no-newline --stderr $diff.stderr

    rm --recursive --force $temp

    if $diff.exit_code > 1 {
        exit $diff.exit_code
    }
}

* Run from the repository root in interactive Stata, not batch mode.
* Render every help file through the actual Viewer and reject exposed SMCL.
version 13.0
set more off

local helpfiles : dir "ado" files "*.sthlp"
if `"`helpfiles'"' == "" {
    display as error "Run this check from the repository root."
    exit 601
}

tempfile rendered
tempname input
local checked = 0
foreach filename of local helpfiles {
    display as text "Checking `filename'"
    view "ado/`filename'"
    translate @Viewer "`rendered'", translator(Viewer2txt) replace
    file open `input' using "`rendered'", read text
    file read `input' line
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', "\{(p_end|pstd|phang|title|cmd|helpb|synopt|p2col|psee|opt|it|bf|browse)") {
            file close `input'
            display as error "Visible SMCL in `filename':"
            display as error `"`macval(line)'"'
            exit 9
        }
        file read `input' line
    }
    file close `input'
    local ++checked
}
display as result "PASS: `checked' help files rendered without exposed SMCL."

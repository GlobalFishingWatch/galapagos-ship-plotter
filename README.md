# Galapagos Ship Plotter

This projects is used to upload data from logs of park positional Galapagos organization.

## How to run?

### normalize

`python -m normalize <TYPE> <PARAM>`

There is a normalization file that can normalize the:
- data: A complete line passed in PARAM, expecting a line of 11 fields separated by ';'
- date: Converts the PARAM to a readable timestamp.
- float: Converts the PARAM to a float cutting the string part.
- degree: Converts the PARAM to a float having in mind the degree minutes and seconds.
- latlon: Converts the PARAM to a float using the orientation to set the sign.

### parser

`sh parser.sh <DIR> >> parser.log`

The parser looks for in the DIR directory where the log files for ship plotter are.
Creates a dir `in_progress` where to parses the data.
Reads line by line and normalize.
Avoids the lines that has more than elevent fields.
Logs the lines that can not be parsed by the normalizer and store them in `<DIR>/cannot_normalize`.
Stores the lines that are correctly normalized in a CSV and store them in `<DIR>/csv`.
Moves the reader shipplotterXXXXX.log to `<DIR>/done` once the file was processed.

### upload

`sh upload <DIR>`


Uploads all the CSV from the <DIR> to the scratch_matias in BQ.


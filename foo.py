import sys

# TODO(ncooke3): Test other edge cases.

# Get the file name from the user.
filename = sys.argv[1]

# Open the file in read-only mode.
with open(filename, "r") as f:

    # Read the file line by line.
    for line in f:
        # Print the line to the console.
        if "-[" in line:
            idx1 = line.index("-[")
            idx2 = line.index("]")

            res = line[idx1: idx2 + 1]
            print(res)

        elif "+[" in line:
            idx1 = line.index("+[")
            idx2 = line.index("]")

            res = line[idx1: idx2 + 1]
            print(res)

# Close the file.
f.close()

file_name=$1

echo "vscode markdown to gitpage mathjax ======"
echo "file name is $file_name"


# latex 2 mathjax only need to change inline $ to $$

# $ to $$
sed -i 's/\$/\$\$/g' $file_name

# $$$$ to $$ again
sed -i 's/\$\$\$\$/\$\$/g' $file_name

file_name=$1
echo "file name is $file_name"
# == == to **
sed -i 's/==/**/g' $file_name

# ```math to $$
sed -i 's/```math/\$\$/g' $file_name

# ``` to $$
sed -i 's/```/\$\$/g' $file_name

# `$ to $$
sed -i 's/`\$/\$\$/g' $file_name

sed -i 's/\$`/\$\$/g' $file_name
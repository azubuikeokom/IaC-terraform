#Note
Use the following code before you push .tf file to github.
** git filter-branch -f --index-filter 'git rm --cached -r --ignore-unmatch .terraform/ **
Adding .terraform/ to gitignore just didn't work
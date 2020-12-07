DATABASE_PATHS=("FirebaseDatabase.*" \
  ".github/workflows/database\\.yml" \
  "Example/Database/" \
  "Interop/Auth/Public/\.\*.h")
FUNCTIONS_PATHS=("Functions.*" \
  ".github/workflows/functions\\.yml" \
  "Interop/Auth/Public/\.\*.h" \
  "FirebaseMessaging/Sources/Interop/\.\*.h")

echo "::set-output name=database_run_job::false"
echo "::set-output name=functions_run_job::false"
echo "=============== list changed files ==============="
cat < <(git diff --name-only HEAD^ HEAD)
echo "========== check paths of changed files =========="
git diff --name-only HEAD^ HEAD > files.txt
while IFS= read -r file
do
  echo $file
  for path in "${DATABASE_PATHS[@]}"
  do
    if [[ "${file}" =~ $path ]]; then
      echo "This file is updated under the path, ${path}"
      echo "::set-output name=database_run_job::true"
      break
    fi
  done
  for path in "${FUNCTIONS_PATHS[@]}"
  do
    if [[ "${file}" =~ $path ]]; then
      echo "This file is updated under the path, ${path}"
      echo "::set-output name=functions_run_job::true"
      break
    fi
  done
done < files.txt


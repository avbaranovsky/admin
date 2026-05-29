#!/bin/bash
config_file="./cert.cfg"
body_file="letter_body.txt"
body_template_file="letter_body.tpl"
cert_file="usercert.pem"
csv_file="./users.csv"

export CERT_USER=""
export CERT_FILE=""
export CERT_FULL=""
export CERT_MAILTO=""
export CERT_DEVICE=""

usage() {
    echo "$0 <login> <device>";
}

check_args() {
    export "CERT_USER=$1"
    export "CERT_DEVICE=$2"

    if [ -z "$CERT_USER" ]; then
        echo "Error: user not specified." >&2
        usage
        return 1
    fi

    if [ -z "$CERT_DEVICE" ]; then
        echo "Error: device not specified." >&2
        usage
        return 1
    fi

    return 0
}

cleanup() {
    rm -f $body_file
    rm -f $CERT_FILE
    rm -f $CERT_NAME.key
    rm -f $CERT_NAME.csr
    rm -f $CERT_NAME.crt
}

check_files() {
    if [ ! -f "$config_file" ]; then
        echo "Error: configuration file $config_file not found." >&2
        return 1
    fi

    if [ ! -f "$csv_file" ]; then
        echo "Error: users file $csv_file not found." >&2
        return 1
    fi

    if [ -z "$body_template_file" ] || [ ! -f "$body_template_file" ]; then
        echo "Error: message template file $body_template_file not found." >&2
        return 1
    fi

    if [ -z "$body_file" ] ; then
        echo "Error: message body file not specified." >&2
        return 1
    fi
    return 0
}

# Функция для загрузки переменных из файла
load_config() {
    while IFS='=' read -r key value; do
        # skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

        # trimming strings
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        # make global variable
        export "$key=$value"
    done < "$config_file"
}

load_user() {
    # Поиск строки по точному совпадению логина (первое поле до запятой)
    local line
    line=$(grep -i "^${CERT_USER}," "$csv_file" | head -n 1)

    if [[ -n "$line" ]]; then
        # Разделение строки на 3 переменные по запятой
        local login full_name email
        IFS=',' read -r login full_name email <<< "$line"
        # Экспорт полного имени и email в переменные окружения
        export "CERT_FULL=$full_name"
        export "CERT_MAILTO=$email"
        return 0
    else
        echo "User '$CERT_USER' not found." >&2
        return 1
    fi
}

build_cert() {
    export "CERT_NAME=$CERT_USER-$CERT_DEVICE"
    export "CERT_PASS=`pwgen 12 1`"
    openssl genrsa -out $CERT_NAME.key 4096 || return 1
    openssl req -new -key $CERT_NAME.key -out $CERT_NAME.csr -subj "/CN=${CERT_NAME}" || return 1
    openssl x509 -req -days 365 -in $CERT_NAME.csr -CA $CA_CERT_PATH -CAkey $CA_KEY_PATH -CAcreateserial -out $CERT_NAME.crt -sha256 || return 1
    export "CERT_FILE=${CERT_NAME}.p12"
    openssl pkcs12 -export -out $CERT_FILE -inkey $CERT_NAME.key -in $CERT_NAME.crt -certfile $CA_CERT_PATH -passout env:CERT_PASS || return 1
    return 0
}

render_message() {
    if envsubst < "$body_template_file" > "$body_file"; then
        return 0
    else
        echo "Error processing template file $body_template_file by envsubst." >&2
        rm -f "$body_file"
        return 1
    fi
}

send_email() {
    if [ ! -f "$body_file" ]; then
        echo "Error: letter body '$body_file' not found." >&2
        return 1
    fi

    # 2. Проверка наличия вложения
    if [ ! -f "$CERT_FILE" ]; then
        echo "Error: Attachment file '$CERT_FILE' not found." >&2
        return 1
    fi

    # 3. Encoding subject and name using  Base64 для UTF-8
    local encoded_subject="=?UTF-8?B?$(echo -n "$MAIL_SUBJ" | base64 | tr -d '\n')?="
    local encoded_name="=?UTF-8?B?$(echo -n "$MAIL_NAME" | base64 | tr -d '\n')?="

    # Make From field
    local from_header="${encoded_name} <${MAIL_FROM}>"

    # 4. Отправка через curl
    curl --url "$MAIL_SMTP" \
      --ssl-reqd \
      --mail-from "$MAIL_FROM" \
      --mail-rcpt "$CERT_MAILTO" \
      --user "$MAIL_USER:$MAIL_PASS" \
      -H "From: $from_header" \
      -H "To: $CERT_MAILTO" \
      -H "Subject: $encoded_subject" \
      -F '=(;type=multipart/mixed)' \
      -F "=<${body_file};type=text/plain;charset=utf-8" \
      -F "=@${CERT_FILE};encoder=base64" \
      -F '=)'

    return $?
}

check_args $1 $2 || exit 1;
check_files || exit 1;
load_config "config.txt" || exit 1;
load_user || exit 1;
build_cert || { cleanup; exit 1; }
render_message || { cleanup; exit 1; }
send_email || { cleanup; exit 1; }
cleanup

exit 0

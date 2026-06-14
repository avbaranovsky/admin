admin - various tools and scripts for system administtation
-----------------------------------------------------------

newcert.sh - issue new client certificate and send it by email

Usage

newcert.sh <user> <device>

program looks users.csv for specified user to get it's full name and
e-mail address then it generates new client certificate, sign it with
provided CA and pack into P12 format. Then it send packed certificate
and password to user's email.

cert.cfg file should contain some configuration parameters:
#e-mail options
MAIL_FROM - System Adminiatrator's e-mail
MAIL_NAME - System Adminiatrator's full name
MAIL_SUBJ - Subject of letter with cerficate
MAIL_USER - login name at SMTP server used to send
MAIL_SMTP - URL to SMTP server in form smtps://smtp.sample.dom:port
MAIL_PASS - password to access to SMTP server

#cert options
CA_CERT_PATH - path to your CA certificate, used by protected server
CA_KEY_PATH - path to your CA certificate, used by protected server

letter_body.tpl file is a template to e-mail message. ${} variables
will be substituted by its values.

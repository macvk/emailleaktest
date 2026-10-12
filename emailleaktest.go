// Email IP leak test client for bash.ws.
// Project: https://github.com/macvk/emailleaktest
// SPDX-License-Identifier: MIT

package main

import (
	"bufio"
	"bytes"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/mail"
	"net/smtp"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"time"
)

const (
	version      = "1.0.0"
	apiDomain    = "bash.ws"
	pollInterval = time.Second
	requestLimit = 30 * time.Second
)

type apiText string

func (value *apiText) UnmarshalJSON(data []byte) error {
	var text string

	if err := json.Unmarshal(data, &text); err == nil {
		*value = apiText(text)
		return nil
	}

	if bytes.Equal(data, []byte("false")) || bytes.Equal(data, []byte("null")) {
		*value = ""
		return nil
	}

	return errors.New("invalid text value in API response")
}

type apiRecord struct {
	IP          apiText `json:"ip"`
	CountryName apiText `json:"country_name"`
	ASN         apiText `json:"asn"`
	Done        apiText `json:"done"`
	Type        string  `json:"type"`
}

type apiClient struct {
	base string
	http *http.Client
}

func newClient() *apiClient {
	return &apiClient{
		base: "https://" + apiDomain,
		http: &http.Client{Timeout: requestLimit},
	}
}

func (client *apiClient) request(path string) ([]byte, error) {
	request, err := http.NewRequest(http.MethodGet, client.base+path, nil)

	if err != nil {
		return nil, err
	}

	request.Header.Set("User-Agent", "bash.ws emailleaktest-go/"+version)
	response, err := client.http.Do(request)

	if err != nil {
		return nil, err
	}

	defer response.Body.Close()

	data, err := io.ReadAll(response.Body)

	if err != nil {
		return nil, err
	}

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return nil, fmt.Errorf("%s returned HTTP %d", path, response.StatusCode)
	}

	return bytes.TrimSpace(data), nil
}

func (client *apiClient) testID() (string, error) {
	data, err := client.request("/id")

	if err != nil {
		return "", err
	}

	value := strings.ToLower(string(data))

	if len(value) != 16 {
		return "", errors.New("invalid test ID returned by /id")
	}

	for _, character := range value {
		if (character < '0' || character > '9') && (character < 'a' || character > 'z') {
			return "", errors.New("invalid test ID returned by /id")
		}
	}

	return value, nil
}

func decodeRecords(data []byte) ([]apiRecord, error) {
	var records []apiRecord

	if err := json.Unmarshal(data, &records); err == nil {
		return records, nil
	}

	var response struct {
		Error string `json:"error"`
	}

	if err := json.Unmarshal(data, &response); err == nil && response.Error != "" {
		return nil, errors.New(response.Error)
	}

	return nil, errors.New("invalid response from the email leak test")
}

func (client *apiClient) result(testID string) ([]apiRecord, error) {
	data, err := client.request("/email-leak-test/test/" + testID + "?json")

	if err != nil {
		return nil, err
	}

	return decodeRecords(data)
}

func prompt(reader *bufio.Reader, label string, defaultValue string) (string, error) {
	if defaultValue == "" {
		fmt.Printf("%s: ", label)
	} else {
		fmt.Printf("%s [%s]: ", label, defaultValue)
	}

	value, err := reader.ReadString('\n')

	if err != nil && !errors.Is(err, io.EOF) {
		return "", err
	}

	value = strings.TrimSpace(value)

	if value == "" {
		value = defaultValue
	}

	return value, nil
}

func sendWithMail(executable string, recipient string) error {
	command := exec.Command(executable, "-s", "Test", recipient)
	command.Stdin = strings.NewReader("")
	command.Stdout = io.Discard
	command.Stderr = os.Stderr

	if err := command.Run(); err != nil {
		return errors.New("email was not sent")
	}

	return nil
}

func readPassword() ([]byte, error) {
	if runtime.GOOS == "windows" {
		script := "$password = Read-Host 'SMTP password' -AsSecureString; " +
			"$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password); " +
			"try { [Console]::Out.Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)) } " +
			"finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }"
		command := exec.Command("powershell.exe", "-NoLogo", "-NoProfile", "-Command", script)
		command.Stdin = os.Stdin
		command.Stderr = os.Stderr
		password, err := command.Output()

		if err != nil {
			return nil, err
		}

		return bytes.TrimRight(password, "\r\n"), nil
	}

	fmt.Print("SMTP password: ")
	script := "stty -echo || exit 1\n" +
		"trap 'stty echo' 0 1 2 15\n" +
		"IFS= read -r password\n" +
		"status=$?\n" +
		"stty echo\n" +
		"trap - 0 1 2 15\n" +
		"printf '\\n' >&2\n" +
		"[ \"$status\" -eq 0 ] || exit \"$status\"\n" +
		"printf '%s' \"$password\""
	command := exec.Command("sh", "-c", script)
	command.Stdin = os.Stdin
	command.Stderr = os.Stderr
	password, err := command.Output()

	if err != nil {
		return nil, err
	}

	return password, nil
}

func sendWithSMTP(recipient string) error {
	reader := bufio.NewReader(os.Stdin)
	senderValue, err := prompt(reader, "Sender email", "")

	if err != nil {
		return errors.New("unable to read SMTP settings")
	}

	sender, err := mail.ParseAddress(senderValue)

	if err != nil || sender.Address != senderValue {
		return errors.New("invalid sender email")
	}

	separator := strings.LastIndexByte(sender.Address, '@')

	if separator <= 0 || separator == len(sender.Address)-1 {
		return errors.New("invalid sender email")
	}

	server, err := prompt(reader, "SMTP server", "smtp."+sender.Address[separator+1:])

	if err != nil {
		return errors.New("unable to read SMTP settings")
	}

	portValue, err := prompt(reader, "SMTP port", "587")

	if err != nil {
		return errors.New("unable to read SMTP settings")
	}

	port, err := strconv.Atoi(portValue)

	if err != nil || port < 1 || port > 65535 {
		return errors.New("invalid SMTP port")
	}

	username, err := prompt(reader, "SMTP username", sender.Address)

	if err != nil {
		return errors.New("unable to read SMTP settings")
	}

	password, err := readPassword()

	if err != nil {
		return errors.New("unable to read SMTP password")
	}

	address := net.JoinHostPort(server, strconv.Itoa(port))
	connection, err := net.DialTimeout("tcp", address, requestLimit)

	if err != nil {
		return fmt.Errorf("email was not sent: %w", err)
	}

	client, err := smtp.NewClient(connection, server)

	if err != nil {
		connection.Close()
		return fmt.Errorf("email was not sent: %w", err)
	}

	defer client.Close()

	if supported, _ := client.Extension("STARTTLS"); !supported {
		return errors.New("SMTP server does not support STARTTLS")
	}

	if err := client.StartTLS(&tls.Config{ServerName: server, MinVersion: tls.VersionTLS12}); err != nil {
		return fmt.Errorf("email was not sent: %w", err)
	}

	if err := client.Auth(smtp.PlainAuth("", username, string(password), server)); err != nil {
		return fmt.Errorf("email was not sent: %w", err)
	}

	if err := client.Mail(sender.Address); err != nil {
		return fmt.Errorf("email was not sent: %w", err)
	}

	if err := client.Rcpt(recipient); err != nil {
		return fmt.Errorf("email was not sent: %w", err)
	}

	writer, err := client.Data()

	if err != nil {
		return fmt.Errorf("email was not sent: %w", err)
	}

	message := "From: " + sender.Address + "\r\n" +
		"To: " + recipient + "\r\n" +
		"Subject: Test\r\n\r\n"

	if _, err := io.WriteString(writer, message); err != nil {
		writer.Close()
		return fmt.Errorf("email was not sent: %w", err)
	}

	if err := writer.Close(); err != nil {
		return fmt.Errorf("email was not sent: %w", err)
	}

	if err := client.Quit(); err != nil {
		return fmt.Errorf("email was not sent: %w", err)
	}

	return nil
}

func sendEmail(testID string) error {
	recipient := testID + "@" + apiDomain
	executable, err := exec.LookPath("mail")

	if err == nil {
		return sendWithMail(executable, recipient)
	}

	return sendWithSMTP(recipient)
}

func testComplete(records []apiRecord) bool {
	for _, record := range records {
		if record.Type == "done" {
			return string(record.Done) == "1"
		}
	}

	return false
}

func formatAddress(record apiRecord) string {
	address := string(record.IP)
	country := string(record.CountryName)
	asn := string(record.ASN)

	if country == "" {
		return address
	}

	if asn == "" {
		return fmt.Sprintf("%s [%s]", address, country)
	}

	return fmt.Sprintf("%s [%s, %s]", address, country, asn)
}

func recordsOfType(records []apiRecord, recordType string) []apiRecord {
	selected := []apiRecord{}

	for _, record := range records {
		if record.Type == recordType && record.IP != "" {
			selected = append(selected, record)
		}
	}

	return selected
}

func printResult(records []apiRecord) error {
	addresses := recordsOfType(records, "ip")
	mailAddresses := recordsOfType(records, "mail")
	conclusions := recordsOfType(records, "conclusion")

	fmt.Println("Your IP:")

	for _, record := range addresses {
		fmt.Println(formatAddress(record))
	}

	fmt.Println()

	switch len(mailAddresses) {
	case 0:
		fmt.Println("No IPs found in mail header")
	case 1:
		fmt.Println("Mail header has got 1 IP:")
	default:
		fmt.Printf("Mail header has got %d IPs:\n", len(mailAddresses))
	}

	for _, record := range mailAddresses {
		fmt.Println(formatAddress(record))
	}

	if len(conclusions) == 0 {
		return errors.New("conclusion missing from the email leak test result")
	}

	fmt.Println()
	fmt.Println("Conclusion:")

	for _, record := range conclusions {
		fmt.Println(record.IP)
	}

	return nil
}

func run() error {
	client := newClient()
	testID, err := client.testID()

	if err != nil {
		return err
	}

	if _, err := client.result(testID); err != nil {
		return err
	}

	if err := sendEmail(testID); err != nil {
		return err
	}

	for {
		time.Sleep(pollInterval)
		records, err := client.result(testID)

		if err != nil {
			return err
		}

		if testComplete(records) {
			fmt.Println()
			return printResult(records)
		}
	}
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "Email leak test failed:", err)
		os.Exit(1)
	}
}

package main

import (
	"bufio"
	"bytes"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

const origin = "http://tokilearning.org"

var phpsessid string

func get(path string) *http.Response {
	client := &http.Client{}

	req, _ := http.NewRequest("GET", origin+path, nil)
	req.AddCookie(&http.Cookie{Name: "PHPSESSID", Value: phpsessid})

	resp, err := client.Do(req)
	if err != nil {
		log.Fatal("error downloading", path)
	}

	return resp
}

func getList(body []byte, search string) []string {
	scanner := bufio.NewScanner(bytes.NewReader(body))
	re := regexp.MustCompile(search)

	result := make([]string, 0)
	reinquote := regexp.MustCompile(`"[^"]+"`)
	for scanner.Scan() {
		line := scanner.Text()
		if re.MatchString(line) {
			quoted := reinquote.FindString(line)
			result = append(result, quoted[1:len(quoted)-1])
		}
	}

	return result
}

func findsub(body []byte, rawstr string) (string, bool) {
	re, err := regexp.Compile(rawstr)
	if err != nil {
		log.Fatal(err)
	}
	match := re.FindSubmatch(body)
	if len(match) < 2 {
		return "", false
	}
	return string(match[1]), true
}

func getTitle(body []byte) string {
	title, _ := findsub(body, `<title>TOKI Learning Center - ([^<]+)</title>`)
	return title
}

func escape(title string) string {
	repl := strings.NewReplacer(
		" ", "_",
		":", "-",
		"&", "DAN",
		",", "",
		"?", "",
		"'", "",
		"+", "PLUS")
	return repl.Replace(strings.ToUpper(title))
}

func getBody(path string) []byte {
	resp := get(path)
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Fatal(err)
	}
	return body
}

func grep(body []byte, rawstr string, nextline bool) (string, bool) {
	re, err := regexp.Compile(rawstr)
	if err != nil {
		log.Fatal(err)
	}
	scanner := bufio.NewScanner(bytes.NewReader(body))
	for scanner.Scan() {
		line := scanner.Text()
		if re.MatchString(line) {
			if nextline {
				_ = scanner.Scan()
				return scanner.Text(), true
			}
			return line, true
		}
	}
	return "", false
}

func grepsub(body []byte, linematch, submatch string, nextline bool) (string, bool) {
	line, ok := grep(body, linematch, nextline)
	if !ok {
		return "", false
	}
	return findsub([]byte(line), submatch)
}

func getProp(body []byte, prop, submatch string) string {
	property, _ := grepsub(body, `<span class="name">`+prop+`</span>`, submatch, true)
	return property
}

func getSubmissionPath(body []byte) (string, bool) {
	return grepsub(body, "<td>Accepted</td>", `href="([^"]+)"`, false)
}

func chdir(dirname string) {
	err := os.Chdir(dirname)
	if err != nil {
		log.Fatal(err)
	}
}

func remove(dirname string) {
	err := os.Remove(dirname)
	if err != nil {
		log.Fatal(err)
	}
}

func getCurrentDir() string {
	cwd, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		log.Fatal(err)
	}
	return cwd
}

func makeDirp(dirname string) {
	if _, err := os.Stat(dirname); os.IsNotExist(err) {
		err := os.Mkdir(dirname, 0755)
		if err != nil {
			log.Fatal(err)
		}
	}
}

func writeToFile(body io.Reader, filename string) {
	file, err := os.Create(filename)
	if err != nil {
		log.Fatal("failed in creating", filename)
	}
	_, err = io.Copy(file, body)
	if err != nil {
		log.Fatal("failed in writing", filename)
	}
}

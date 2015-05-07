package main

import (
	"fmt"
	"log"
	"os"
	"strings"
)

const tgpath = "/training/7/chapter/46"

func processAll() {
	log.Println("dowloading chapter list at", tgpath)
	body := getBody(tgpath)

	list := getList(body, "chapter-link")
	for _, path := range list {
		log.Println("processing chapter at", path)
		processChapter(path)
	}
}

func processChapter(path string) {
	body := getBody(path)

	title := getTitle(body)
	log.Println("title =", title)

	list := getList(body, "chapter-link")
	for _, path := range list {
		log.Println("processing subchapter at", path)
		processSubChapter(path)
	}
}

func processSubChapter(path string) {
	body := getBody(path)

	title := getTitle(body)
	log.Println("title =", title)

	dirname := escape(title)
	cwd := getCurrentDir()
	makeDirp(dirname)
	chdir(dirname)

	repl := strings.NewReplacer("problem", "submission")
	exist := false
	// TODO: check another page, maybe ?page=x with x > 2. But how!
	list := getList(body, "problem-link")
	if _, ok := grep(body, `class="next"`, false); ok {
		p2body := getBody(path + "?page=2")
		p2list := getList(p2body, "problem-link")
		list = append(list, p2list...)
	}
	for _, path := range list {
		submpath := repl.Replace(path)
		log.Println("processing problem submission at", submpath)
		ac := processSubmission(submpath)
		if !ac {
			log.Println("no accepted submission")
		}
		exist = exist || ac
	}

	chdir(cwd)
	if !exist {
		remove(dirname)
	}
}

func processSubmission(path string) bool {
	body := getBody(path)

	submpath, ok := getSubmissionPath(body)
	if !ok {
		return false
	}

	log.Println("submission path =", submpath)

	submbody := getBody(submpath)

	name := getProp(submbody, "Soal", `^.*<a [^>]+> *([^<]+) *</a>.*$`)
	lang := getProp(submbody, "Bahasa Pemrograman", `^.*<span> *([^<]+) *</span>.*$`)

	dlpath := submpath + "?action=download"
	filename := escape(name) + "." + lang

	log.Printf("downloading %s (%s)\n", name, filename)

	dlresp := get(dlpath)
	defer dlresp.Body.Close()

	writeToFile(dlresp.Body, filename)

	return true
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s [PHPSESSID]\n", os.Args[0])
		os.Exit(1)
	}
	phpsessid = os.Args[1]
	processAll()
}

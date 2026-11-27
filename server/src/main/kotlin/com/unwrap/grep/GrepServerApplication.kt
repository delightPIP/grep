package com.unwrap.grep

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class GrepServerApplication

fun main(args: Array<String>) {
	runApplication<GrepServerApplication>(*args)
}

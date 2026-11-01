package main

import (
	"context"
	"flag"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	addr := flag.String("listen", "127.0.0.1:8080", "loopback HTTP listener behind a TLS proxy")
	flag.Parse()
	host, _, err := net.SplitHostPort(*addr)
	if err != nil || net.ParseIP(host) == nil || !net.ParseIP(host).IsLoopback() {
		log.Fatal("listen must be a loopback IP and port; expose only through a TLS proxy")
	}
	s := newRelay()
	httpServer := &http.Server{Addr: *addr, Handler: s, ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 30 * time.Second, MaxHeaderBytes: 8192}
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	go func() {
		timer := time.NewTicker(100 * time.Millisecond)
		defer timer.Stop()
		for {
			select {
			case now := <-timer.C:
				s.sweep(now)
			case <-ctx.Done():
				return
			}
		}
	}()
	go func() {
		<-ctx.Done()
		s.stop()
		shutdown, stop := context.WithTimeout(context.Background(), 5*time.Second)
		defer stop()
		httpServer.Shutdown(shutdown)
	}()
	log.Printf("RiftDuel relay listening on %s", *addr)
	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}

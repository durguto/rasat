package stream

import (
	"sort"

	"github.com/durguto/rasat/internal/store"
)

func sortByTimestampAsc(rows []store.TraceListRow) {
	sort.SliceStable(rows, func(i, j int) bool {
		return rows[i].Timestamp.Before(rows[j].Timestamp)
	})
}

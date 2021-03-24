using System;

namespace PsFCIV.Support {
    public class IntStatTable {
        public Int32 Total { get; set; }
        public Int32 New { get; set; }
        public Int32 Ok { get; set; }
        public Int32 Bad { get; set; }
        public Int32 Missed { get; set; }
        public Int32 Locked { get; set; }
        public Int32 Unknown { get; set; }
        public Int32 Deleted { get; set; }
    }
}
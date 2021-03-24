using System;
using System.Collections.Generic;

namespace PsFCIV.Support {
    public class StatTable {
        public List<String> Total { get; } = new List<String>();
        public List<String> New { get; } = new List<String>();
        public List<String> Ok { get; } = new List<String>();
        public List<String> Bad { get; } = new List<String>();
        public List<String> Missed { get; } = new List<String>();
        public List<String> Locked { get; } = new List<String>();
        public List<String> Unknown { get; } = new List<String>();
        public Int32 Deleted { get; set; }
    }
}
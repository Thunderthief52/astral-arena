using System;
using LSLib.LS;
using LSLib.LS.Enums;

class P {
    static int Main(string[] a) {
        var load = ResourceLoadParameters.FromGameVersion(Game.BaldursGate3);
        var save = ResourceConversionParameters.FromGameVersion(Game.BaldursGate3);
        var res = ResourceUtils.LoadResource(a[0], load);
        ResourceUtils.SaveResource(res, a[1], save);
        Console.WriteLine("ok " + a[1]);
        return 0;
    }
}

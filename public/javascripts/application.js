if (typeof yamb == 'undefined') { window.yamb = {}; }
jq = jQuery;

yamb.loadChart = function(target, stats) {
  debugger;
  google.load('visualization', '1', {packages:['imageareachart']});
  google.setOnLoadCallback(function () {
    var data = new google.visualization.DataTable();
    data.addColumn('string', 'day');
    data.addColumn('number', 'new users that day');
    data.addRows(7);

    data.setValue(0, 0, '7 days ago');
    data.setValue(0, 1, stats[0]);

    data.setValue(1, 0, '6 days ago');
    data.setValue(1, 1, stats[1]);

    data.setValue(2, 0, '5 days ago');
    data.setValue(2, 1, stats[2]);

    data.setValue(3, 0, '4 days ago');
    data.setValue(3, 1, stats[3]);

    data.setValue(4, 0, '3 days ago');
    data.setValue(4, 1, stats[4]);

    data.setValue(5, 0, '2 days ago');
    data.setValue(5, 1, stats[5]);

    data.setValue(6, 0, '1 days ago');
    data.setValue(6, 1, stats[6]);

    var chart = new google.visualization.ImageAreaChart(jq("#" + target)[0]);
    chart.draw(data, {legend: 'none', showCategoryLabels: false, showValueLabels: false, width: 200, height: 50, max: 0, min: 0, backgroundColor: '4b4b4b00'});
  });
}

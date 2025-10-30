from flask import Flask, render_template, request, redirect, url_for, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func
from zapv2 import ZAPv2
import sys
sys.path.append('/home/chada/zapproject/zapvenv/lib/python3.13/site-packages')
import os
from dotenv import load_dotenv
import time
from datetime import datetime
from urllib.parse import quote_plus
load_dotenv("/etc/myflaskapp/.env")



#Caling Environment Variables

# --- CONFIG ---
app = Flask(__name__)
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")
DB_NAME = os.getenv("DB_NAME")
DB_HOST = os.getenv("DB_HOST")
ZAP_PORT = os.getenv("ZAP_PORT")
ZAP_HOST = os.getenv("ZAP_HOST")
API_KEY = os.getenv("API_KEY")
app.config['API_KEY'] = os.getenv('API_KEY')
REPORT_DIR = os.getenv("REPORT_DIR", "/home/chada/zapproject/reports")
app.config['SQLALCHEMY_DATABASE_URI'] = f"mariadb+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)
zap = ZAPv2(apikey=app.config['API_KEY'],
            proxies={'http': f"http://{os.getenv('ZAP_HOST')}:{os.getenv('ZAP_PORT')}",
                     'https': f"http://{os.getenv('ZAP_HOST')}:{os.getenv('ZAP_PORT')}"})

os.makedirs(REPORT_DIR, exist_ok=True)

#...................................................................
# --- DATABASE MODEL ---
class scanner_results(db.Model):
    __tablename__ = "zap_scan"
    id = db.Column(db.Integer, primary_key=True)
    target_url = db.Column(db.String(255))
    risk= db.Column(db.String(50))
    alert = db.Column(db.String(255))
    description = db.Column(db.Text)
    solution = db.Column(db.Text)
    scanned_at = db.Column(db.DateTime(timezone=True))
    
# --- ROUTES ---
@app.route('/',methods=['GET', 'POST'])
def index():

    if request.method == 'POST':
        target_url = request.form['url']
        return redirect(url_for('scan', target_url=target_url))
    return render_template('index.html')

@app.route('/scan')
def scan():
    target_url = request.args.get('target_url')
    print(target_url)
    time.sleep(2)

    # Access the URL
    zap.urlopen(target_url)
    time.sleep(2)

    # Save report
    filename = f"{target_url.replace('http://', '').replace('https://', '').replace('/', '_')}_report.html"
    report_path = os.path.join(REPORT_DIR, filename)
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(zap.core.htmlreport())


    # Save to DB
    result = scanner_results(target_url=target_url)
    db.session.add(result)
    db.session.commit()
    return render_template('results.html', report_name=filename)

@app.route('/download/<report_name>')
def download(report_name):
    return send_from_directory(REPORT_DIR, report_name, as_attachment=True)

# --- MAIN ---
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000, debug=True)
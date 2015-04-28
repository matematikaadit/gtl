# GTL
Grab Tokilearning

Script for grabbing source code of accepted submission in [Tokilearning](http://tokilearning.org/).

## Usage

1. Login to [Tokilearning](http://tokilearning.org/)
2. Open Developer Console (CTRL+SHIFT+K in firefox, CTRL+SHIFT+J in chrome) and copy the following script:

    ```js
    c=document.cookie.split('; ');k={};for(var i=0;i<c.length;i++){p=c[i].split('=');k[p[0]]=p[1];};console.log(k['PHPSESSID'])
    ```

3. You'll get PHPSESSID of your login session. Copy that string and use it in the following command.

    ```sh
    ./gtl.sh [PHPSESSID]
    ```

4. Profit

## License

MIT License. See [LICENSE](LICENSE)
